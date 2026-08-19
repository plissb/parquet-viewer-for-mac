import XCTest
@testable import ParquetViewer

final class ParquetEngineTests: XCTestCase {
    func testFlatFileOverviewAndPage() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        let overview = try await engine.fileOverview()
        XCTAssertEqual(overview.rowCount, 500)
        XCTAssertEqual(overview.columnCount, 6)
        XCTAssertFalse(overview.compressionCodecs.isEmpty)

        let schema = try await engine.schema()
        let names = schema.map(\.name)
        XCTAssertEqual(names, ["id", "name", "score", "active", "day", "seen_at"])
        XCTAssertEqual(schema.first?.kind, .integer)

        let page = try await engine.page(offset: 0, limit: 10)
        XCTAssertEqual(page.rows.count, 10)
        XCTAssertEqual(page.columns, names)
        XCTAssertEqual(page.rows[0][0], "0")
        XCTAssertNil(page.rows[0][1])
        XCTAssertEqual(page.rows[1][1], "user_1")

        let last = try await engine.page(offset: 490, limit: 20)
        XCTAssertEqual(last.rows.count, 10)
        XCTAssertEqual(last.rows.last?[0], "499")
        await engine.close()
    }

    func testNestedColumnsRenderAsJSON() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("nested.parquet"))
        let schema = try await engine.schema()
        XCTAssertEqual(schema.map(\.name), ["id", "address", "scores"])
        XCTAssertEqual(schema[1].kind, .nested)
        XCTAssertEqual(schema[2].kind, .nested)

        let page = try await engine.page(offset: 0, limit: 1)
        XCTAssertEqual(page.rows.count, 1)
        let address = try XCTUnwrap(page.rows[0][1])
        XCTAssertTrue(address.contains("city"), address)
        let scores = try XCTUnwrap(page.rows[0][2])
        XCTAssertTrue(scores.hasPrefix("["), scores)
        await engine.close()
    }

    func testEmptyFileHasSchemaAndNoRows() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("empty.parquet"))
        let overview = try await engine.fileOverview()
        XCTAssertEqual(overview.rowCount, 0)
        XCTAssertEqual(overview.columnCount, 2)
        let page = try await engine.page(offset: 0, limit: 50)
        XCTAssertTrue(page.rows.isEmpty)
        await engine.close()
    }

    func testWideFileColumnCount() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("wide.parquet"))
        let overview = try await engine.fileOverview()
        XCTAssertEqual(overview.columnCount, 81)
        XCTAssertEqual(overview.rowCount, 2000)
        let page = try await engine.page(offset: 0, limit: 5)
        XCTAssertEqual(page.columns.count, 81)
        XCTAssertEqual(page.rows.count, 5)
        await engine.close()
    }

    func testApostrophePath() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("O'Brien.parquet"))
        let overview = try await engine.fileOverview()
        XCTAssertEqual(overview.rowCount, 500)
        await engine.close()
    }

    func testColumnStatsForFlatId() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        let stats = try await engine.columnStats()
        let id = try XCTUnwrap(stats["id"])
        XCTAssertEqual(id.min, "0")
        XCTAssertEqual(id.max, "499")
        await engine.close()
    }

    func testFilterWhereClause() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        let page = try await engine.page(offset: 0, limit: 50, source: .table(whereClause: "id >= 490"))
        XCTAssertEqual(page.totalRows, 10)
        XCTAssertEqual(page.rows.count, 10)
        XCTAssertEqual(page.rows.first?[0], "490")
        await engine.close()
    }

    func testSQLQueryProjection() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        let page = try await engine.page(
            offset: 0,
            limit: 10,
            source: .sql("SELECT id, name FROM data WHERE id < 3")
        )
        XCTAssertEqual(page.columns, ["id", "name"])
        XCTAssertEqual(page.totalRows, 3)
        XCTAssertEqual(page.rows.count, 3)
        XCTAssertEqual(page.rows[1][1], "user_1")
        await engine.close()
    }

    func testSQLAggregation() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        let page = try await engine.page(offset: 0, limit: 5, source: .sql("SELECT count(*) AS n FROM data"))
        XCTAssertEqual(page.columns, ["n"])
        XCTAssertEqual(page.rows.first?[0], "500")
        await engine.close()
    }

    func testInvalidFilterFails() async throws {
        let engine = ParquetEngine()
        try await engine.open(url: fixture("flat.parquet"))
        do {
            _ = try await engine.page(offset: 0, limit: 10, source: .table(whereClause: "not_a_column = 1"))
            XCTFail("expected failure")
        } catch let error as ParquetEngineError {
            guard case .queryFailed = error else {
                return XCTFail("wrong error \(error)")
            }
        }
        await engine.close()
    }

    func testNotParquetFails() async throws {
        let junk = FileManager.default.temporaryDirectory.appendingPathComponent("not.parquet")
        try Data("hello".utf8).write(to: junk)
        let engine = ParquetEngine()
        do {
            try await engine.open(url: junk)
            XCTFail("expected failure")
        } catch let error as ParquetEngineError {
            guard case .notParquet = error else {
                return XCTFail("wrong error \(error)")
            }
        }
        await engine.close()
    }

    private func fixture(_ name: String) throws -> URL {
        let bundle = Bundle(for: ParquetEngineTests.self)
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        if let url = bundle.url(forResource: stem, withExtension: ext, subdirectory: "Fixtures") {
            return url
        }
        if let url = bundle.url(forResource: stem, withExtension: ext) {
            return url
        }
        let fallback = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        XCTFail("missing fixture \(name)")
        throw URLError(.fileDoesNotExist)
    }
}
