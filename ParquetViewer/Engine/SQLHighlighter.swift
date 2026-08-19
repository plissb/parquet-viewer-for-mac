import AppKit
import Foundation

enum SQLTokenKind: Equatable {
    case keyword
    case field
    case table
    case string
    case number
    case comment
    case identifier
    case whitespace
    case other
}

struct SQLToken: Equatable {
    var kind: SQLTokenKind
    var text: String
    var utf16Range: NSRange
}

enum SQLHighlighter {
    static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL", "LIKE", "ILIKE",
        "BETWEEN", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL", "CROSS", "NATURAL",
        "ON", "USING", "GROUP", "BY", "ORDER", "LIMIT", "OFFSET", "AS", "ASC", "DESC",
        "CASE", "WHEN", "THEN", "ELSE", "END", "HAVING", "UNION", "ALL", "DISTINCT",
        "WITH", "RECURSIVE", "EXISTS", "ANY", "SOME", "FILTER", "WINDOW", "OVER",
        "PARTITION", "QUALIFY", "DESCRIBE", "SHOW", "SUMMARIZE", "PIVOT", "UNPIVOT",
        "EXCEPT", "INTERSECT", "CAST", "TRUE", "FALSE", "COUNT", "SUM", "AVG", "MIN",
        "MAX", "CREATE", "REPLACE", "VIEW", "TABLE", "INSERT", "UPDATE", "DELETE",
        "VALUES", "INTO", "SET", "RETURNING", "LATERAL", "UNNEST", "ANTI", "SEMI",
    ]

    static func tokens(
        in source: String,
        fields: Set<String>,
        tables: Set<String> = ["data"]
    ) -> [SQLToken] {
        let fieldNames = Set(fields.map { $0.lowercased() })
        let tableNames = Set(tables.map { $0.lowercased() })
        var tokens: [SQLToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            let start = index
            let character = source[index]

            if character.isWhitespace {
                index = source[index...].firstIndex(where: { !$0.isWhitespace }) ?? source.endIndex
                tokens.append(makeToken(.whitespace, source, start, index))
                continue
            }

            if character == "-", source.index(after: index) < source.endIndex, source[source.index(after: index)] == "-" {
                index = source[index...].firstIndex(of: "\n") ?? source.endIndex
                tokens.append(makeToken(.comment, source, start, index))
                continue
            }

            if character == "/", source.index(after: index) < source.endIndex, source[source.index(after: index)] == "*" {
                index = source.index(start, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                while index < source.endIndex {
                    if source[index] == "*", source.index(after: index) < source.endIndex,
                       source[source.index(after: index)] == "/" {
                        index = source.index(index, offsetBy: 2)
                        break
                    }
                    index = source.index(after: index)
                }
                tokens.append(makeToken(.comment, source, start, index))
                continue
            }

            if character == "'" || character == "\"" {
                let quote = character
                index = source.index(after: index)
                while index < source.endIndex {
                    if source[index] == quote {
                        let next = source.index(after: index)
                        if next < source.endIndex, source[next] == quote {
                            index = source.index(after: next)
                            continue
                        }
                        index = next
                        break
                    }
                    index = source.index(after: index)
                }
                let kind: SQLTokenKind = quote == "'" ? .string : identifierKind(
                    raw: String(source[start..<index]),
                    fields: fieldNames,
                    tables: tableNames,
                    quoted: true
                )
                tokens.append(makeToken(kind, source, start, index))
                continue
            }

            if character.isNumber || (character == "." && peekIsDigit(source, after: index)) {
                index = source.index(after: index)
                while index < source.endIndex {
                    let current = source[index]
                    if current.isNumber || current == "." || current == "_" {
                        index = source.index(after: index)
                    } else {
                        break
                    }
                }
                tokens.append(makeToken(.number, source, start, index))
                continue
            }

            if isIdentifierHead(character) {
                index = source.index(after: index)
                while index < source.endIndex, isIdentifierBody(source[index]) {
                    index = source.index(after: index)
                }
                let raw = String(source[start..<index])
                let kind = identifierKind(raw: raw, fields: fieldNames, tables: tableNames, quoted: false)
                tokens.append(makeToken(kind, source, start, index))
                continue
            }

            index = source.index(after: index)
            tokens.append(makeToken(.other, source, start, index))
        }

        return tokens
    }

    static func baseAttributes(fontSize: CGFloat = 12) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: Palette.nsInk,
            .obliqueness: 0,
        ]
    }

    static func attributed(
        _ source: String,
        fields: [String],
        selectedField: String?,
        fontSize: CGFloat = 12
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source)
        style(result, fields: fields, selectedField: selectedField, fontSize: fontSize)
        return result
    }

    static func style(
        _ storage: NSMutableAttributedString,
        fields: [String],
        selectedField: String?,
        fontSize: CGFloat = 12
    ) {
        let source = storage.string
        let tokens = tokens(in: source, fields: Set(fields))
        let selected = selectedField?.lowercased()
        let base = baseAttributes(fontSize: fontSize)
        let full = NSRange(location: 0, length: storage.length)
        guard full.length > 0 else { return }
        storage.beginEditing()
        storage.setAttributes(base, range: full)

        for token in tokens {
            guard token.kind != .whitespace, token.utf16Range.length > 0,
                  NSMaxRange(token.utf16Range) <= storage.length else { continue }
            var attributes = base
            switch token.kind {
            case .keyword:
                attributes[.foregroundColor] = Palette.nsBrass
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            case .field:
                let isSelected = selected.map { bareName(token.text).lowercased() == $0 } ?? false
                attributes[.foregroundColor] = Palette.nsChip(.text)
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: fontSize, weight: isSelected ? .bold : .medium)
            case .table:
                attributes[.foregroundColor] = Palette.nsBrass
                attributes[.font] = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium)
            case .string:
                attributes[.foregroundColor] = Palette.nsChip(.boolean)
            case .number:
                attributes[.foregroundColor] = Palette.nsChip(.floating)
            case .comment:
                attributes[.foregroundColor] = Palette.nsMuted
                attributes[.obliqueness] = 0.15
            case .identifier:
                attributes[.foregroundColor] = Palette.nsInk
            case .other:
                attributes[.foregroundColor] = Palette.nsMuted
            case .whitespace:
                break
            }
            storage.addAttributes(attributes, range: token.utf16Range)
        }
        storage.endEditing()
    }

    static func fieldName(in source: String, utf16Range: NSRange, fields: [String]) -> String? {
        let fieldSet = Set(fields)
        let tokens = tokens(in: source, fields: fieldSet)
        let location: Int
        if utf16Range.length == 0 {
            location = max(utf16Range.location - 1, 0)
        } else {
            location = utf16Range.location
        }
        guard let token = tokens.first(where: { NSLocationInRange(location, $0.utf16Range) || NSEqualRanges($0.utf16Range, utf16Range) }) else {
            return nil
        }
        guard token.kind == .field else { return nil }
        let name = bareName(token.text)
        return fields.first { $0.compare(name, options: [.caseInsensitive, .literal]) == .orderedSame } ?? name
    }

    static func bareName(_ token: String) -> String {
        if token.count >= 2, token.hasPrefix("\""), token.hasSuffix("\"") {
            let inner = token.dropFirst().dropLast()
            return inner.replacingOccurrences(of: "\"\"", with: "\"")
        }
        return token
    }

    private static func identifierKind(
        raw: String,
        fields: Set<String>,
        tables: Set<String>,
        quoted: Bool
    ) -> SQLTokenKind {
        let name = quoted ? bareName(raw) : raw
        let folded = name.lowercased()
        if !quoted, keywords.contains(name.uppercased()) {
            return .keyword
        }
        if fields.contains(folded) {
            return .field
        }
        if tables.contains(folded) {
            return .table
        }
        return quoted ? .identifier : .identifier
    }

    private static func makeToken(_ kind: SQLTokenKind, _ source: String, _ start: String.Index, _ end: String.Index) -> SQLToken {
        let text = String(source[start..<end])
        let range = NSRange(start..<end, in: source)
        return SQLToken(kind: kind, text: text, utf16Range: range)
    }

    private static func peekIsDigit(_ source: String, after index: String.Index) -> Bool {
        let next = source.index(after: index)
        return next < source.endIndex && source[next].isNumber
    }

    private static func isIdentifierHead(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierBody(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
