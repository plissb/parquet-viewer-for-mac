import Foundation

enum SQLQuotes {
    static func identifier(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func literal(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    static func path(_ url: URL) -> String {
        literal(url.path(percentEncoded: false))
    }

    static func stripTrailingSemicolons(_ sql: String) -> String {
        var text = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix(";") {
            text.removeLast()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    static func whereClause(_ raw: String?) -> String {
        guard let raw else { return "" }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if text.uppercased().hasPrefix("WHERE ") || text.uppercased() == "WHERE" {
            return " \(text)"
        }
        return " WHERE \(text)"
    }
}
