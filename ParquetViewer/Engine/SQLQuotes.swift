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
}
