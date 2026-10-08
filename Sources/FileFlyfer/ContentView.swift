import SwiftUI

struct ContentView: View {
    private enum BrowserViewMode: String, CaseIterable {
        case icons, list, preview
        var icon: String {
            switch self { case .icons: "square.grid.2x2"; case .list: "list.bullet"; case .preview: "rectangle.split.2x1" }
        }
        var title: String {
            switch self { case .icons: "İkon"; case .list: "Liste"; case .preview: "Detay" }
        }
    }

    @ObservedObject var model: AppViewModel
    @State private var viewMode: BrowserViewMode = .list
    @State private var newFolderPresented = false
    @State private var newFolderName = ""
    @State private var renameTarget: RemoteFile?
    @State private var renameText = ""
    @State private var deleteTargets: [RemoteFile] = []

    var body: some View {
        VStack(spacing: 0) {
            deviceBar
            Divider()
            if model.devices.isEmpty {
                OnboardingView(refresh: { Task { await model.refreshDevices() } })
            } else if let device = model.selectedDevice, device.state != .device {
                DeviceProblemView(device: device, refresh: { Task { await model.refreshDevices() } })
            } else {
                browser
            }
            if !model.transfers.isEmpty {
                Divider()
                TransferQueueView(model: model)
            }
        }
        .alert("Yeni Klasör", isPresented: $newFolderPresented) {
            TextField("Klasör adı", text: $newFolderName)
            Button("Oluştur") {
                let name = newFolderName
                newFolderName = ""
                Task { await model.createFolder(named: name) }
            }.disabled(newFolderName.isEmpty)
            Button("Vazgeç", role: .cancel) { newFolderName = "" }
        }
        .alert("Yeniden Adlandır", isPresented: renameBinding) {
            TextField("Yeni ad", text: $renameText)
            Button("Kaydet") {
                if let target = renameTarget { Task { await model.rename(target, to: renameText) } }
                renameTarget = nil
            }.disabled(renameText.isEmpty)
            Button("Vazgeç", role: .cancel) { renameTarget = nil }
        }
        .confirmationDialog("Seçili öğeler silinsin mi?", isPresented: deleteBinding) {
            Button("Sil", role: .destructive) {
                let targets = deleteTargets
                deleteTargets = []
                Task { await model.delete(targets) }
            }
            Button("Vazgeç", role: .cancel) { deleteTargets = [] }
        } message: { Text("Bu işlem geri alınamaz.") }
        .confirmationDialog("Aynı isimli dosya mevcut", isPresented: conflictBinding, presenting: model.conflict) { _ in
            Button("Üzerine Yaz") { model.resolveConflict(overwrite: true) }
            Button("Yeni İsimle Kaydet") { model.resolveConflict(overwrite: false, useNewName: true) }
            Button("Atla", role: .cancel) { model.resolveConflict(overwrite: false) }
        } message: { conflict in
            Text("“\(conflict.item.fileName)” hedefte zaten var.")
        }
        .alert("İşlem tamamlanamadı", isPresented: errorBinding, presenting: model.error) { _ in
            Button("Tamam") { model.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private var deviceBar: some View {
        HStack(spacing: 12) {
            Picker("Cihaz", selection: deviceSelection) {
                if model.devices.isEmpty { Text("Cihaz bulunamadı").tag(String?.none) }
                ForEach(model.devices) { device in
                    Text(device.pickerName).tag(Optional(device.id))
                }
            }
            .frame(width: 380)

            if let device = model.selectedDevice {
                Circle().fill(statusColor(device.state)).frame(width: 8, height: 8)
                Text(device.state.title)
                if let version = device.androidVersion, !version.isEmpty {
                    Text("Android \(version)").foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.isLoading { ProgressView().controlSize(.small) }
            Button { Task { await model.refreshDevices() } } label: {
                Label("Yenile", systemImage: "arrow.clockwise")
            }
        }
        .padding(12)
    }

    private var browser: some View {
        NavigationSplitView {
            List {
                if let device = model.selectedDevice {
                    Section("Cihazınız") {
                        DeviceSummaryView(device: device)
                    }
                }
                Section("Telefon Depolaması") {
                    location("Dahili Depolama", icon: "internaldrive", path: "/sdcard")
                    location("Download", icon: "arrow.down.circle", path: "/sdcard/Download")
                    location("Fotoğraflar (DCIM)", icon: "camera", path: "/sdcard/DCIM")
                    location("Resimler (Pictures)", icon: "photo", path: "/sdcard/Pictures")
                    location("Movies", icon: "film", path: "/sdcard/Movies")
                    location("Music", icon: "music.note", path: "/sdcard/Music")
                    location("Documents", icon: "doc", path: "/sdcard/Documents")
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            VStack(spacing: 0) {
                fileToolbar
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                PathNavigatorView(path: model.currentPath, goUp: model.goUp, navigate: model.navigate)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                fileList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }
        }
    }

    private func location(_ title: LocalizedStringKey, icon: String, path: String) -> some View {
        Button { model.navigate(to: path) } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fileToolbar: some View {
        HStack(spacing: 8) {
            Picker("Görünüm", selection: $viewMode) {
                ForEach(BrowserViewMode.allCases, id: \.self) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            Spacer()
            Button { newFolderPresented = true } label: { Label("Yeni Klasör", systemImage: "folder.badge.plus") }
            Button(action: model.uploadFromPanel) { Label("Gönder", systemImage: "square.and.arrow.up") }
            Button(action: model.downloadFromPanel) { Label("İndir", systemImage: "square.and.arrow.down") }
                .disabled(model.selectedFiles.allSatisfy(\.isDirectory))
            Button { Task { await model.loadFiles() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Listeyi yenile")
        }
        .padding(10)
    }

    private var fileList: some View {
        Group {
            if model.files.isEmpty && !model.isLoading {
                VStack(spacing: 14) {
                    PlaceholderView(
                        title: "Bu klasör boş", icon: "folder",
                        detail: "Dosyaları buraya sürükleyerek telefona gönderebilirsiniz."
                    )
                    .frame(maxHeight: 180)
                    Button { Task { await model.loadFiles() } } label: {
                        Label("Yenile", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewMode {
                case .icons:
                    iconGrid
                case .list:
                    detailList
                case .preview:
                    HSplitView {
                        detailList.frame(minWidth: 320, maxHeight: .infinity)
                        PreviewPane(file: model.selectedFiles.count == 1 ? model.selectedFiles.first : nil,
                                    previewImage: model.previewImage,
                                    isLoading: model.isLoadingPreview)
                            .frame(minWidth: 240, idealWidth: 340, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onChange(of: model.selectedFileIDs) { _ in
            if viewMode == .preview { model.preparePreview() }
        }
        .onChange(of: viewMode) { mode in
            if mode == .preview { model.preparePreview() }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.upload(urls)
            return true
        }
    }

    private var detailList: some View {
        VStack(spacing: 0) {
                    HStack {
                        Text("Ad").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Tür").frame(width: 110, alignment: .leading)
                        Text("Boyut").frame(width: 100, alignment: .trailing)
                        Text("Değiştirilme").frame(width: 150, alignment: .leading)
                    }
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 7)
                    Divider()
                    List(model.files, selection: $model.selectedFileIDs) { file in
                        FileRow(file: file)
                            .tag(file.id)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded { model.open(file) }
                            )
                            .contextMenu {
                                if !file.isDirectory { Button("Mac'e İndir…") { model.selectedFileIDs = [file.id]; model.downloadFromPanel() } }
                                Button("Yeniden Adlandır…") { renameTarget = file; renameText = file.name }
                                Divider()
                                Button("Sil…", role: .destructive) { deleteTargets = [file] }
                            }
                    }
                    .listStyle(.inset)
        }
    }

    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 16) {
                ForEach(model.files) { file in
                    VStack(spacing: 8) {
                        Group {
                            if let thumbnail = model.thumbnailImages[file.id] {
                                Image(nsImage: thumbnail).resizable().scaledToFill()
                            } else {
                                Image(systemName: file.isDirectory ? "folder.fill" : (file.isImage ? "photo" : "doc"))
                                    .resizable().scaledToFit().padding(14)
                                    .foregroundStyle(file.isDirectory ? .blue : .secondary)
                            }
                        }
                        .frame(width: 96, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        Text(file.name).lineLimit(2).multilineTextAlignment(.center)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(model.selectedFileIDs.contains(file.id) ? Color.accentColor.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                    .onAppear { model.loadThumbnail(for: file) }
                    .onTapGesture { model.selectedFileIDs = [file.id] }
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { model.open(file) }
                    )
                    .contextMenu {
                        if !file.isDirectory { Button("Mac'e İndir…") { model.selectedFileIDs = [file.id]; model.downloadFromPanel() } }
                        Button("Yeniden Adlandır…") { renameTarget = file; renameText = file.name }
                        Divider()
                        Button("Sil…", role: .destructive) { deleteTargets = [file] }
                    }
                }
            }
            .padding(18)
        }
    }

    private var deviceSelection: Binding<String?> {
        Binding(get: { model.selectedDeviceID }, set: { model.selectDevice($0) })
    }
    private var errorBinding: Binding<Bool> {
        Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    }
    private var renameBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }
    private var deleteBinding: Binding<Bool> {
        Binding(get: { !deleteTargets.isEmpty }, set: { if !$0 { deleteTargets = [] } })
    }
    private var conflictBinding: Binding<Bool> {
        Binding(get: { model.conflict != nil }, set: { if !$0, model.conflict != nil { model.resolveConflict(overwrite: false) } })
    }
    private func statusColor(_ state: DeviceState) -> Color {
        switch state { case .device: .green; case .unauthorized: .orange; case .offline: .red; case .unknown: .gray }
    }
}

private struct PreviewPane: View {
    let file: RemoteFile?
    let previewImage: NSImage?
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            if let file {
                if isLoading {
                    ProgressView("Önizleme hazırlanıyor…")
                } else if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: file.isDirectory ? "folder.fill" : "doc")
                        .font(.system(size: 72)).foregroundStyle(.secondary)
                }
                Divider()
                Text(file.name).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                HStack {
                    Text(file.isDirectory ? "Klasör" : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                    if let date = file.modifiedAt { Text("•"); Text(date.formatted(date: .abbreviated, time: .shortened)) }
                }
                .font(.caption).foregroundStyle(.secondary)
            } else {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 54)).foregroundStyle(.tertiary)
                Text("Önizlemek için bir dosya seçin").foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}

private struct FileRow: View {
    let file: RemoteFile
    var body: some View {
        HStack {
            Label(file.name, systemImage: file.isDirectory ? "folder.fill" : "doc")
                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(file.isDirectory ? "Klasör" : file.pathExtension.uppercasedOr("Dosya"))
                .frame(width: 110, alignment: .leading).foregroundStyle(.secondary)
            Text(file.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                .frame(width: 100, alignment: .trailing).foregroundStyle(.secondary)
            Text(file.modifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                .frame(width: 150, alignment: .leading).foregroundStyle(.secondary)
        }
    }
}

private extension RemoteFile { var pathExtension: String { NSString(string: name).pathExtension } }
private extension String { func uppercasedOr(_ fallback: String) -> String { isEmpty ? fallback : uppercased() } }
