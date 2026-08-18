import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(Workspace.self) private var workspace

    var body: some View {
        Group {
            if let url = workspace.currentURL {
                InspectorView(url: url)
            } else {
                EmptyDropView()
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(Palette.canvas)
        .onOpenURL { url in
            workspace.open(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openParquetRequested)) { _ in
            workspace.presentOpenPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openParquetURLs)) { note in
            if let urls = note.object as? [URL], let first = urls.first {
                workspace.open(first)
            }
        }
    }
}

extension Notification.Name {
    static let openParquetRequested = Notification.Name("openParquetRequested")
    static let openParquetURLs = Notification.Name("openParquetURLs")
    static let copyCellRequested = Notification.Name("copyCellRequested")
    static let copyRowsRequested = Notification.Name("copyRowsRequested")
}
