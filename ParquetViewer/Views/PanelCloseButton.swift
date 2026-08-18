import SwiftUI

struct PanelCloseButton: View {
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .frame(width: 20, height: 20)
                .background(Palette.hairline.opacity(0.55), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
