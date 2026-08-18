import SwiftUI
import UniformTypeIdentifiers

struct EmptyDropView: View {
    @Environment(Workspace.self) private var workspace
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            Palette.ink.opacity(0.025).ignoresSafeArea().blendMode(.multiply)

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("Parquet Viewer")
                        .font(Typeface.display(42))
                        .foregroundStyle(Palette.ink)
                    Text("A cabinet for columnar files.")
                        .font(Typeface.ui(15))
                        .foregroundStyle(Palette.muted)
                }

                dropWell
                    .frame(width: 460, height: 240)

                Button("Open a file…") {
                    workspace.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                .buttonStyle(.bordered)
                .tint(Palette.brass)
                .controlSize(.large)
            }
            .padding(40)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private var dropWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.well)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Palette.brass.opacity(isTargeted ? 1 : 0.7), lineWidth: isTargeted ? 2 : 1)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 1)
                .padding(10)

            VStack(spacing: 14) {
                Text(".PARQUET")
                    .font(Typeface.mono(12, weight: .medium))
                    .tracking(3.2)
                    .foregroundStyle(Palette.brass)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(
                        Rectangle()
                            .stroke(Palette.brass.opacity(0.7), lineWidth: 1)
                    )

                Text("Drop a file here")
                    .font(Typeface.display(22))
                    .foregroundStyle(Palette.ink)

                Text("or choose one from disk")
                    .font(Typeface.ui(13))
                    .foregroundStyle(Palette.muted)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: isTargeted ? 18 : 8, y: 6)
        .scaleEffect(isTargeted ? 1.015 : 1)
        .animation(.easeOut(duration: 0.18), value: isTargeted)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let value = item as? URL {
                url = value
            } else if let value = item as? NSURL {
                url = value as URL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                workspace.open(url)
            }
        }
        return true
    }
}
