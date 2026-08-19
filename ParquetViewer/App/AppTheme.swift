import AppKit
import SwiftUI

enum Palette {
    static let canvas = Color(light: "F4EFE6", dark: "1C1612")
    static let plank = Color(light: "FFFBF4", dark: "241C16")
    static let ink = Color(light: "2A2118", dark: "F3E6D4")
    static let muted = Color(light: "2A2118", dark: "F3E6D4").opacity(0.62)
    static let brass = Color(light: "8A6A32", dark: "C4A574")
    static let hairline = Color(light: "D9CDBB", dark: "3A2E24")
    static let well = Color(light: "EBE3D4", dark: "18130F")
    static let selected = Color(light: "E8D7B5", dark: "3A2C1E")

    static func chip(_ kind: TypeKind) -> Color {
        switch kind {
        case .integer: Color(light: "5C6B75", dark: "8FA0AB")
        case .floating: Color(light: "2F6F6A", dark: "7FB3AD")
        case .text: Color(light: "9A6B24", dark: "D4A85A")
        case .boolean: Color(light: "5B6A32", dark: "A3B56A")
        case .temporal: Color(light: "8A4A32", dark: "C48468")
        case .nested: Color(light: "5C4E73", dark: "A696C0")
        case .binary: Color(light: "6B6258", dark: "A3988C")
        case .other: Color(light: "6B6258", dark: "A3988C")
        }
    }
}

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

private enum HexRGB {
    static func components(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        return (
            CGFloat((value >> 16) & 0xFF) / 255,
            CGFloat((value >> 8) & 0xFF) / 255,
            CGFloat(value & 0xFF) / 255
        )
    }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = HexRGB.components(hex)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
    }

    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: "swift-palette-\(light)-\(dark)") { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}

extension NSColor {
    static func srgb(hex: String) -> NSColor {
        let (r, g, b) = HexRGB.components(hex)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    static func adaptive(light: String, dark: String) -> NSColor {
        NSColor(name: "ns-palette-\(light)-\(dark)") { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return .srgb(hex: isDark ? dark : light)
        }
    }
}

extension Palette {
    static let nsInk = NSColor.adaptive(light: "2A2118", dark: "F3E6D4")
    static let nsMuted = nsInk.withAlphaComponent(0.62)
    static let nsBrass = NSColor.adaptive(light: "8A6A32", dark: "C4A574")

    static func nsChip(_ kind: TypeKind) -> NSColor {
        switch kind {
        case .integer: integerChip
        case .floating: floatingChip
        case .text: textChip
        case .boolean: booleanChip
        case .temporal: temporalChip
        case .nested: nestedChip
        case .binary, .other: binaryChip
        }
    }

    private static let integerChip = NSColor.adaptive(light: "5C6B75", dark: "8FA0AB")
    private static let floatingChip = NSColor.adaptive(light: "2F6F6A", dark: "7FB3AD")
    private static let textChip = NSColor.adaptive(light: "9A6B24", dark: "D4A85A")
    private static let booleanChip = NSColor.adaptive(light: "5B6A32", dark: "A3B56A")
    private static let temporalChip = NSColor.adaptive(light: "8A4A32", dark: "C48468")
    private static let nestedChip = NSColor.adaptive(light: "5C4E73", dark: "A696C0")
    private static let binaryChip = NSColor.adaptive(light: "6B6258", dark: "A3988C")
}

enum Pasteboard {
    static func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum CountFormat {
    static func string(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
