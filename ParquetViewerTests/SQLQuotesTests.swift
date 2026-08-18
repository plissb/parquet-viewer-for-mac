import XCTest
@testable import ParquetViewer

final class SQLQuotesTests: XCTestCase {
    func testIdentifierEscapesQuotes() {
        XCTAssertEqual(SQLQuotes.identifier("name"), "\"name\"")
        XCTAssertEqual(SQLQuotes.identifier("weird\"col"), "\"weird\"\"col\"")
        XCTAssertEqual(SQLQuotes.identifier("order"), "\"order\"")
    }

    func testLiteralEscapesApostrophes() {
        XCTAssertEqual(SQLQuotes.literal("plain"), "'plain'")
        XCTAssertEqual(SQLQuotes.literal("O'Brien"), "'O''Brien'")
    }

    func testPathQuotesFileURL() {
        let url = URL(fileURLWithPath: "/tmp/O'Brien.parquet")
        XCTAssertEqual(SQLQuotes.path(url), "'/tmp/O''Brien.parquet'")
    }
}
