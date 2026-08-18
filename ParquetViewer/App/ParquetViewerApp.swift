import AppKit
import SwiftUI

@main
struct ParquetViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var workspace = Workspace.shared
    @AppStorage("showsColumnRail") private var showsColumnRail = true
    @AppStorage("showsSpecPlate") private var showsSpecPlate = true

    var body: some Scene {
        Window("Parquet Viewer", id: "main") {
            RootView()
                .environment(workspace)
        }
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    workspace.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Close File") {
                    workspace.closeFile()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(workspace.currentURL == nil)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Copy Cell") {
                    NotificationCenter.default.post(name: .copyCellRequested, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Copy Rows") {
                    NotificationCenter.default.post(name: .copyRowsRequested, object: nil)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
            CommandMenu("View") {
                Button(showsColumnRail ? "Hide Columns" : "Show Columns") {
                    showsColumnRail.toggle()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button(showsSpecPlate ? "Hide File Details" : "Show File Details") {
                    showsSpecPlate.toggle()
                }
                .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .openParquetURLs, object: urls)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }
}
