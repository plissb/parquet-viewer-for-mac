import DuckDB
import Foundation

actor ParquetEngine {
    private var database: Database?
    private var connection: Connection?
    private var fileURL: URL?
    private var quotedPath: String?
    private var describedColumns: [(name: String, type: String)] = []
    private var cachedRowCount: Int64 = 0

    func open(url: URL) async throws {
        closeUnlocked()
        let database = try Database(store: .inMemory)
        let connection = try database.connect()
        self.database = database
        self.connection = connection
        self.fileURL = url
        self.quotedPath = SQLQuotes.path(url)

        do {
            try connection.execute(
                "CREATE OR REPLACE VIEW data AS SELECT * FROM read_parquet(\(SQLQuotes.path(url)))"
            )
            describedColumns = try describeColumns()
            cachedRowCount = try loadRowCount()
        } catch {
            closeUnlocked()
            throw ParquetEngineError.notParquet(Self.reason(from: error))
        }
    }

    func close() {
        closeUnlocked()
    }

    func fileOverview() async throws -> FileOverview {
        let (connection, path, url) = try requireOpen()

        let meta = try query(
            connection,
            """
            SELECT created_by, num_rows, num_row_groups, format_version
            FROM parquet_file_metadata(\(path))
            """
        )

        let createdBy = string(meta, "created_by", row: 0)
        let rowCount = int64(meta, "num_rows", row: 0) ?? cachedRowCount
        let rowGroups = int64(meta, "num_row_groups", row: 0) ?? 0
        let version = int64(meta, "format_version", row: 0) ?? 0
        let fileSize = (try? Int64(url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)) ?? 0

        let codecResult = try query(
            connection,
            """
            SELECT DISTINCT compression
            FROM parquet_metadata(\(path))
            WHERE compression IS NOT NULL
            ORDER BY 1
            """
        )
        let codecs = strings(codecResult, named: "compression").compactMap { $0 }

        var kv: [(key: String, value: String)] = []
        if let kvResult = try? query(
            connection,
            """
            SELECT CAST(key AS VARCHAR) AS key, CAST(value AS VARCHAR) AS value
            FROM parquet_kv_metadata(\(path))
            """
        ) {
            let keys = strings(kvResult, named: "key")
            let values = strings(kvResult, named: "value")
            kv = zip(keys, values).compactMap { key, value -> (key: String, value: String)? in
                guard let key else { return nil }
                return (key, value ?? "")
            }
        }

        return FileOverview(
            path: url,
            fileSize: fileSize,
            rowCount: rowCount,
            columnCount: describedColumns.count,
            rowGroupCount: Int(clamping: rowGroups),
            formatVersion: Int(clamping: version),
            createdBy: createdBy,
            compressionCodecs: codecs,
            kv: kv
        )
    }

    func schema() async throws -> [ColumnNode] {
        let (connection, path, _) = try requireOpen()
        let described = describedColumns.isEmpty ? try describeColumns() : describedColumns

        let parquet = try query(
            connection,
            """
            SELECT name, type, repetition_type, logical_type, converted_type
            FROM parquet_schema(\(path))
            """
        )
        let names = strings(parquet, named: "name")
        let types = strings(parquet, named: "type")
        let reps = strings(parquet, named: "repetition_type")
        let logicals = strings(parquet, named: "logical_type")
        var extra: [String: (type: String?, rep: String?, logical: String?)] = [:]
        for index in names.indices {
            guard let name = names[index] else { continue }
            extra[name] = (types[safe: index] ?? nil, reps[safe: index] ?? nil, logicals[safe: index] ?? nil)
        }

        return described.map { column in
            let info = extra[column.name]
            return ColumnNode(
                id: column.name,
                name: column.name,
                duckType: column.type,
                parquetType: info?.type,
                logicalType: info?.logical,
                repetition: info?.rep
            )
        }
    }

    func columnStats() async throws -> [String: ColumnStats] {
        let (connection, path, _) = try requireOpen()
        let result = try query(
            connection,
            """
            SELECT
                path_in_schema,
                SUM(stats_null_count) AS null_count,
                MAX(stats_distinct_count) AS distinct_count,
                MIN(stats_min_value) AS min_value,
                MAX(stats_max_value) AS max_value,
                SUM(total_compressed_size) AS compressed,
                SUM(total_uncompressed_size) AS uncompressed,
                any_value(compression) AS compression,
                any_value(encodings) AS encodings
            FROM parquet_metadata(\(path))
            GROUP BY path_in_schema
            """
        )

        let paths = strings(result, named: "path_in_schema")
        var stats: [String: ColumnStats] = [:]
        for (index, pathName) in paths.enumerated() {
            guard let pathName else { continue }
            let encodingsRaw = string(result, "encodings", row: index) ?? ""
            stats[pathName] = ColumnStats(
                nullCount: int64(result, "null_count", row: index),
                distinctCount: int64(result, "distinct_count", row: index),
                min: string(result, "min_value", row: index),
                max: string(result, "max_value", row: index),
                compressedBytes: int64(result, "compressed", row: index) ?? 0,
                uncompressedBytes: int64(result, "uncompressed", row: index) ?? 0,
                encodings: encodingsRaw
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                compression: string(result, "compression", row: index)
            )
        }
        return stats
    }

    func page(offset: Int, limit: Int, source: ResultSource = .table(whereClause: nil)) async throws -> DataPage {
        let (connection, _, _) = try requireOpen()
        let from = try fromClause(source)
        let columns = try describeSource(from)
        let safeOffset = max(0, offset)
        let safeLimit = min(max(1, limit), 500)
        let total = try countSource(from)

        let selectList: String
        if columns.isEmpty {
            selectList = "*"
        } else {
            selectList = columns.map { column in
                let ident = SQLQuotes.identifier(column.name)
                if TypeKind(duckType: column.type).isNested {
                    return "to_json(\(ident)) AS \(ident)"
                }
                return "CAST(\(ident) AS VARCHAR) AS \(ident)"
            }.joined(separator: ", ")
        }

        let result = try query(
            connection,
            """
            SELECT \(selectList)
            FROM \(from)
            LIMIT \(safeLimit) OFFSET \(safeOffset)
            """
        )

        let names = columns.map(\.name)
        let types = columns.map(\.type)
        let typed = names.indices.map { result[DBInt($0)].cast(to: String.self) }
        let rowCount = Int(clamping: result.rowCount)
        var rows: [[String?]] = []
        rows.reserveCapacity(rowCount)
        for row in 0..<rowCount {
            let index = DBInt(row)
            rows.append(typed.map { $0[index] })
        }

        return DataPage(
            columns: names,
            columnTypes: types,
            rows: rows,
            offset: safeOffset,
            limit: safeLimit,
            totalRows: total
        )
    }

    private func closeUnlocked() {
        connection = nil
        database = nil
        fileURL = nil
        quotedPath = nil
        describedColumns = []
        cachedRowCount = 0
    }

    private func requireOpen() throws -> (Connection, String, URL) {
        guard let connection, let quotedPath, let fileURL else {
            throw ParquetEngineError.notOpen
        }
        return (connection, quotedPath, fileURL)
    }

    private func describeColumns() throws -> [(name: String, type: String)] {
        try describeSource("data")
    }

    private func fromClause(_ source: ResultSource) throws -> String {
        switch source {
        case .table(let whereClause):
            return "data\(SQLQuotes.whereClause(whereClause))"
        case .sql(let sql):
            let cleaned = SQLQuotes.stripTrailingSemicolons(sql)
            guard !cleaned.isEmpty else {
                throw ParquetEngineError.queryFailed("Query is empty.")
            }
            let head = cleaned.prefix(while: { !$0.isWhitespace }).uppercased()
            let allowed = ["SELECT", "WITH", "FROM", "DESCRIBE", "SHOW", "SUMMARIZE", "PIVOT"]
            guard allowed.contains(head) else {
                throw ParquetEngineError.queryFailed("Only queries that return rows are supported.")
            }
            return "(\(cleaned)) AS query_result"
        }
    }

    private func describeSource(_ from: String) throws -> [(name: String, type: String)] {
        let (connection, _, _) = try requireOpen()
        let result = try query(connection, "DESCRIBE SELECT * FROM \(from)")
        let names = strings(result, named: "column_name")
        let types = strings(result, named: "column_type")
        return zip(names, types).compactMap { name, type in
            guard let name, let type else { return nil }
            return (name, type)
        }
    }

    private func countSource(_ from: String) throws -> Int64 {
        let (connection, _, _) = try requireOpen()
        let counted = try query(connection, "SELECT count(*) AS n FROM \(from)")
        return int64(counted, "n", row: 0) ?? 0
    }

    private func loadRowCount() throws -> Int64 {
        let (connection, path, _) = try requireOpen()
        let meta = try query(connection, "SELECT num_rows FROM parquet_file_metadata(\(path))")
        if let count = int64(meta, "num_rows", row: 0) {
            return count
        }
        let counted = try query(connection, "SELECT count(*) AS n FROM read_parquet(\(path))")
        return int64(counted, "n", row: 0) ?? 0
    }

    private func query(_ connection: Connection, _ sql: String) throws -> ResultSet {
        do {
            return try connection.query(sql)
        } catch {
            throw ParquetEngineError.queryFailed(Self.reason(from: error))
        }
    }

    private func strings(_ result: ResultSet, named: String) -> [String?] {
        guard let index = result.index(forColumnName: named) else {
            return Array(repeating: nil, count: Int(clamping: result.rowCount))
        }
        let column = result[index].cast(to: String.self)
        return (0..<result.rowCount).map { column[$0] }
    }

    private func string(_ result: ResultSet, _ name: String, row: Int) -> String? {
        strings(result, named: name)[safe: row] ?? nil
    }

    private func int64(_ result: ResultSet, _ name: String, row: Int) -> Int64? {
        guard let index = result.index(forColumnName: name) else { return nil }
        let signed = result[index].cast(to: Int64.self)[DBInt(row)]
        if let signed { return signed }
        if let unsigned = result[index].cast(to: UInt64.self)[DBInt(row)] {
            return Int64(clamping: unsigned)
        }
        if let asInt = result[index].cast(to: Int.self)[DBInt(row)] {
            return Int64(asInt)
        }
        if let asString = result[index].cast(to: String.self)[DBInt(row)] {
            return Int64(asString)
        }
        return nil
    }

    private static func reason(from error: Error) -> String {
        if let error = error as? DatabaseError {
            switch error {
            case .connectionQueryError(let reason),
                 .databaseFailedToInitialize(let reason),
                 .preparedStatementFailedToInitialize(let reason),
                 .preparedStatementQueryError(let reason):
                if let reason, !reason.isEmpty { return reason }
            default:
                break
            }
        }
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("DuckDB.DatabaseError") {
            return String(describing: error)
        }
        return text.isEmpty ? String(describing: error) : text
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
