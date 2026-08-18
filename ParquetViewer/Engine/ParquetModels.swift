import Foundation

enum TypeKind: String, Sendable, CaseIterable {
    case integer
    case floating
    case text
    case boolean
    case temporal
    case nested
    case binary
    case other

    init(duckType: String) {
        let type = duckType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if type.hasSuffix("[]") || type.hasPrefix("STRUCT") || type.hasPrefix("LIST")
            || type.hasPrefix("MAP") || type.hasPrefix("UNION") || type.hasPrefix("ARRAY") {
            self = .nested
        } else if type == "BOOLEAN" || type == "BOOL" {
            self = .boolean
        } else if type == "FLOAT" || type == "DOUBLE" || type.hasPrefix("DECIMAL") || type.hasPrefix("NUMERIC") {
            self = .floating
        } else if type.contains("DATE") || type.contains("TIME") || type.contains("INTERVAL") {
            self = .temporal
        } else if type == "BLOB" || type == "BIT" || type == "BITSTRING" {
            self = .binary
        } else if type.contains("INT") || type == "HUGEINT" || type == "UHUGEINT" {
            self = .integer
        } else if type == "VARCHAR" || type == "UUID" || type == "JSON" || type.hasPrefix("ENUM") {
            self = .text
        } else {
            self = .other
        }
    }

    var label: String {
        switch self {
        case .integer: "INT"
        case .floating: "FLOAT"
        case .text: "TEXT"
        case .boolean: "BOOL"
        case .temporal: "TIME"
        case .nested: "NESTED"
        case .binary: "BIN"
        case .other: "DATA"
        }
    }

    var isNested: Bool { self == .nested }
}

struct FileOverview: Sendable, Equatable {
    var path: URL
    var fileSize: Int64
    var rowCount: Int64
    var columnCount: Int
    var rowGroupCount: Int
    var formatVersion: Int
    var createdBy: String?
    var compressionCodecs: [String]
    var kv: [(key: String, value: String)]

    static func == (lhs: FileOverview, rhs: FileOverview) -> Bool {
        lhs.path == rhs.path
            && lhs.fileSize == rhs.fileSize
            && lhs.rowCount == rhs.rowCount
            && lhs.columnCount == rhs.columnCount
            && lhs.rowGroupCount == rhs.rowGroupCount
            && lhs.formatVersion == rhs.formatVersion
            && lhs.createdBy == rhs.createdBy
            && lhs.compressionCodecs == rhs.compressionCodecs
            && lhs.kv.map(\.key) == rhs.kv.map(\.key)
            && lhs.kv.map(\.value) == rhs.kv.map(\.value)
    }
}

struct ColumnNode: Sendable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var duckType: String
    var parquetType: String?
    var logicalType: String?
    var repetition: String?
    var children: [ColumnNode] = []

    var kind: TypeKind { TypeKind(duckType: duckType) }
}

struct ColumnStats: Sendable, Equatable {
    var nullCount: Int64?
    var distinctCount: Int64?
    var min: String?
    var max: String?
    var compressedBytes: Int64
    var uncompressedBytes: Int64
    var encodings: [String]
    var compression: String?
}

struct DataPage: Sendable, Equatable {
    var columns: [String]
    var rows: [[String?]]
    var offset: Int
    var limit: Int
    var totalRows: Int64

    var isEmpty: Bool { rows.isEmpty }
    var endRow: Int { min(offset + rows.count, Int(clamping: totalRows)) }

    func cell(row: Int, column: String) -> String? {
        guard rows.indices.contains(row),
              let index = columns.firstIndex(of: column) else { return nil }
        return rows[row][index]
    }
}

enum ParquetEngineError: LocalizedError, Equatable {
    case notOpen
    case notParquet(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notOpen:
            "No parquet file is open."
        case .notParquet(let message):
            "This file could not be read as parquet. \(message)"
        case .queryFailed(let message):
            message
        }
    }
}
