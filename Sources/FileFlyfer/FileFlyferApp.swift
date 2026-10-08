import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct FileFlyferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 920, minHeight: 620)
                .task { model.start() }
                .onDisappear { model.stop() }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Dosya Gönder…") { model.uploadFromPanel() }
                    .keyboardShortcut("u", modifiers: [.command])
                Button("Seçilenleri İndir…") { model.downloadFromPanel() }
                    .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}
