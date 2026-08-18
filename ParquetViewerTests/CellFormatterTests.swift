import XCTest
@testable import ParquetViewer

final class CellFormatterTests: XCTestCase {
    func testNullDisplayAndCopy() {
        XCTAssertEqual(CellFormatter.display(nil), "—")
        XCTAssertEqual(CellFormatter.copyValue(nil), "")
        XCTAssertEqual(CellFormatter.display("ok"), "ok")
    }

    func testTruncation() {
        let long = String(repeating: "a", count: 300)
        let cut = CellFormatter.truncated(long, limit: 10)
        XCTAssertTrue(cut.hasSuffix("…"))
        XCTAssertEqual(cut.count, 11)
        XCTAssertEqual(CellFormatter.truncated("short", limit: 10), "short")
    }

    func testTSV() {
        let tsv = CellFormatter.tsv(
            columns: ["id", "name"],
            rows: [[ "1", "Ada"], [nil, "O\tBrien"]]
        )
        XCTAssertEqual(tsv, "id\tname\n1\tAda\n\tO Brien")
    }

    func testPageCellLookup() {
        let page = DataPage(
            columns: ["id", "name"],
            rows: [["0", nil], ["1", "Ada"]],
            offset: 0,
            limit: 2,
            totalRows: 2
        )
        XCTAssertEqual(page.cell(row: 1, column: "name"), "Ada")
        XCTAssertNil(page.cell(row: 0, column: "name"))
        XCTAssertNil(page.cell(row: 2, column: "id"))
        XCTAssertNil(page.cell(row: 0, column: "missing"))
    }

    func testSelectedRowsKeepOrder() {
        let page = DataPage(
            columns: ["id"],
            rows: [["0"], ["1"], ["2"], ["3"]],
            offset: 0,
            limit: 4,
            totalRows: 4
        )
        let picked = IndexSet([3, 1]).sorted().compactMap { page.rows.indices.contains($0) ? page.rows[$0] : nil }
        XCTAssertEqual(picked, [["1"], ["3"]])
        XCTAssertEqual(CellFormatter.tsv(columns: page.columns, rows: picked), "id\n1\n3")
    }

    func testTypeKindClassification() {
        XCTAssertEqual(TypeKind(duckType: "INTEGER"), .integer)
        XCTAssertEqual(TypeKind(duckType: "BIGINT"), .integer)
        XCTAssertEqual(TypeKind(duckType: "DOUBLE"), .floating)
        XCTAssertEqual(TypeKind(duckType: "VARCHAR"), .text)
        XCTAssertEqual(TypeKind(duckType: "BOOLEAN"), .boolean)
        XCTAssertEqual(TypeKind(duckType: "TIMESTAMP"), .temporal)
        XCTAssertEqual(TypeKind(duckType: "STRUCT(city VARCHAR)"), .nested)
        XCTAssertEqual(TypeKind(duckType: "INTEGER[]"), .nested)
        XCTAssertEqual(TypeKind(duckType: "BLOB"), .binary)
    }
}
