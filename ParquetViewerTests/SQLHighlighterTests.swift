import XCTest
@testable import ParquetViewer

final class SQLHighlighterTests: XCTestCase {
    func testKeywordsAndFields() {
        let tokens = SQLHighlighter.tokens(
            in: "SELECT id, name FROM data WHERE score > 1",
            fields: ["id", "name", "score"]
        )
        let kinds = tokens.filter { $0.kind != .whitespace && $0.kind != .other }.map { ($0.text, $0.kind) }
        XCTAssertEqual(kinds.map(\.0), ["SELECT", "id", "name", "FROM", "data", "WHERE", "score", "1"])
        XCTAssertEqual(kinds.map(\.1), [
            .keyword, .field, .field, .keyword, .table, .keyword, .field, .number,
        ])
    }

    func testStringsAndCommentsAreNotFields() {
        let tokens = SQLHighlighter.tokens(
            in: "SELECT 'id' FROM data -- name\n",
            fields: ["id", "name"]
        )
        XCTAssertTrue(tokens.contains { $0.kind == .string && $0.text == "'id'" })
        XCTAssertTrue(tokens.contains { $0.kind == .comment && $0.text.contains("name") })
        XCTAssertFalse(tokens.contains { $0.kind == .field && $0.text == "id" })
    }

    func testSelectedFieldLookup() {
        let sql = "SELECT id, name FROM data"
        let id = SQLHighlighter.fieldName(
            in: sql,
            utf16Range: NSRange(location: 7, length: 2),
            fields: ["id", "name"]
        )
        XCTAssertEqual(id, "id")
        XCTAssertNil(
            SQLHighlighter.fieldName(
                in: sql,
                utf16Range: NSRange(location: 0, length: 6),
                fields: ["id", "name"]
            )
        )
    }

    func testAttributedSelectedFieldIsBold() {
        let text = SQLHighlighter.attributed(
            "SELECT id, name FROM data",
            fields: ["id", "name"],
            selectedField: "name"
        )
        let nameRange = (text.string as NSString).range(of: "name")
        let font = text.attribute(.font, at: nameRange.location, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.fontDescriptor.symbolicTraits.contains(.bold), true)
        let idRange = (text.string as NSString).range(of: "id")
        let idFont = text.attribute(.font, at: idRange.location, effectiveRange: nil) as? NSFont
        XCTAssertNotEqual(idFont?.fontDescriptor.symbolicTraits.contains(.bold), true)
    }

    func testAttributedTokensUseDistinctColors() {
        let text = SQLHighlighter.attributed(
            "SELECT id FROM data WHERE name = 'Ada' -- note",
            fields: ["id", "name"],
            selectedField: nil
        )
        func color(of fragment: String) -> NSColor? {
            let range = (text.string as NSString).range(of: fragment)
            return text.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
        }
        XCTAssertEqual(color(of: "SELECT"), Palette.nsBrass)
        XCTAssertEqual(color(of: "id"), Palette.nsChip(.text))
        XCTAssertEqual(color(of: "'Ada'"), Palette.nsChip(.boolean))
        XCTAssertEqual(color(of: "-- note"), Palette.nsMuted)
        XCTAssertNotEqual(color(of: "SELECT"), color(of: "id"))
        XCTAssertNotEqual(color(of: "SELECT"), color(of: "'Ada'"))
    }
}
