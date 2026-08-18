import SwiftUI

struct TypeChip: View {
    let kind: TypeKind

    var body: some View {
        Text(kind.label)
            .font(Typeface.mono(9, weight: .medium))
            .tracking(0.6)
            .foregroundStyle(Palette.chip(kind))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .stroke(Palette.chip(kind).opacity(0.45), lineWidth: 1)
            )
    }
}
