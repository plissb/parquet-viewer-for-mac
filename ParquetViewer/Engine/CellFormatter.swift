import Foundation

enum CellFormatter {
    static let displayNull = "—"
    static let copyNull = ""

    static func truncated(_ value: String, limit: Int = 240) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
    }

    static func display(_ value: String?) -> String {
        guard let value else { return displayNull }
        return truncated(value)
    }

    static func copyValue(_ value: String?) -> String {
        value ?? copyNull
    }

    static func tsv(columns: [String], rows: [[String?]]) -> String {
        let header = columns.joined(separator: "\t")
        let body = rows.map { row in
            row.map { copyValue($0).replacingOccurrences(of: "\t", with: " ") }.joined(separator: "\t")
        }
        return ([header] + body).joined(separator: "\n")
    }
}
