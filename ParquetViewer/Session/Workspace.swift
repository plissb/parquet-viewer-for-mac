import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class Workspace {
    static let shared = Workspace()

    var currentURL: URL?
    private var accessingURL: URL?

    func open(_ url: URL) {
        stopAccess()
        var scoped = url
        if !scoped.startAccessingSecurityScopedResource() {
            scoped = url.standardizedFileURL
            _ = scoped.startAccessingSecurityScopedResource()
        }
        accessingURL = scoped
        currentURL = scoped
        NSDocumentController.shared.noteNewRecentDocumentURL(scoped)
        NSApp.windows.first?.title = scoped.lastPathComponent
    }

    func closeFile() {
        stopAccess()
        currentURL = nil
        NSApp.windows.first?.title = "Parquet Viewer"
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.parquet, .data]
        panel.title = "Open Parquet File"
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    private func stopAccess() {
        accessingURL?.stopAccessingSecurityScopedResource()
        accessingURL = nil
    }
}
