import AppKit

extension AppViewModel {
    func uploadFromPanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Telefona gönderilecek dosyaları seçin")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK { upload(panel.urls) }
    }

    func downloadFromPanel() {
        guard !selectedFiles.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = String(localized: "Mac'te hedef klasörü seçin")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { downloadSelected(to: url) }
    }
}
