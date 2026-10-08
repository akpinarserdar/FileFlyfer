import AppKit
import Combine
import Foundation
import ImageIO

@MainActor
final class AppViewModel: ObservableObject {
    struct TransferConflict: Identifiable {
        let id = UUID()
        let item: TransferItem
    }
    @Published var devices: [AndroidDevice] = []
    @Published var selectedDeviceID: String?
    @Published var currentPath = "/sdcard"
    @Published var files: [RemoteFile] = []
    @Published var selectedFileIDs = Set<RemoteFile.ID>()
    @Published var transfers: [TransferItem] = []
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var technicalError: String?
    @Published var conflict: TransferConflict?
    @Published var previewURL: URL?
    @Published var previewImage: NSImage?
    @Published var isLoadingPreview = false
    @Published var thumbnailImages: [RemoteFile.ID: NSImage] = [:]

    private let service: ADBServicing
    private var monitoringTask: Task<Void, Never>?
    private var transferTask: Task<Void, Never>?
    private var previewRequestID = UUID()
    private var loadingThumbnailIDs = Set<RemoteFile.ID>()
    private var pendingConflicts: [TransferConflict] = []
    private var loadedLocationKey: String?

    init(service: ADBServicing = ADBService()) { self.service = service }

    var selectedDevice: AndroidDevice? { devices.first { $0.id == selectedDeviceID } }
    var selectedFiles: [RemoteFile] { files.filter { selectedFileIDs.contains($0.id) } }

    func start() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            await self?.refreshDevices()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await self?.refreshDevices(silent: true)
            }
        }
    }

    func stop() { monitoringTask?.cancel(); monitoringTask = nil }

    func refreshDevices(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            var found = try await service.devices()
            await withTaskGroup(of: AndroidDevice.self) { group in
                for device in found where device.state == .device {
                    group.addTask { [service] in (try? await service.deviceDetails(for: device)) ?? device }
                }
                var details: [String: AndroidDevice] = [:]
                for await device in group { details[device.id] = device }
                found = found.map { details[$0.id] ?? $0 }
            }
            let previous = selectedDeviceID
            devices = found
            if let previous, found.contains(where: { $0.id == previous }) {
                selectedDeviceID = previous
            } else {
                selectedDeviceID = found.first(where: { $0.state == .device })?.id ?? found.first?.id
            }
            if let device = selectedDevice, device.state == .device {
                let locationKey = "\(device.id):\(currentPath)"
                if previous != selectedDeviceID || loadedLocationKey != locationKey { await loadFiles() }
            } else {
                files = []
                loadedLocationKey = nil
            }
        } catch {
            // The monitor runs every three seconds. A background failure updates
            // naturally on the next pass and must not reopen a dismissed alert.
            if !silent { present(error) }
        }
    }

    func selectDevice(_ id: String?) {
        selectedDeviceID = id
        currentPath = "/sdcard"
        files = []
        loadedLocationKey = nil
        Task { await loadFiles() }
    }

    func navigate(to path: String) { currentPath = path; Task { await loadFiles() } }

    func open(_ file: RemoteFile) {
        guard file.isDirectory else { return }
        navigate(to: file.path)
    }

    func preparePreview() {
        previewRequestID = UUID()
        let requestID = previewRequestID
        previewURL = nil
        previewImage = nil
        isLoadingPreview = false
        guard let device = selectedDevice,
              selectedFiles.count == 1,
              let file = selectedFiles.first,
              !file.isDirectory,
              file.isImage else { return }

        if thumbnailImages[file.id] != nil {
            previewURL = cachedImageURL(for: file, device: device)
            previewImage = loadImage(at: cachedImageURL(for: file, device: device), maxPixelSize: 1600)
            return
        }
        isLoadingPreview = true
        Task { [weak self] in
            guard let self else { return }
            let local = self.cachedImageURL(for: file, device: device)
            do {
                try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await self.service.pull(remote: file.path, local: local, device: device)
                if let image = self.loadImage(at: local, maxPixelSize: 240) { self.thumbnailImages[file.id] = image }
                guard self.previewRequestID == requestID, self.selectedFileIDs == [file.id] else { return }
                self.previewURL = local
                self.previewImage = self.loadImage(at: local, maxPixelSize: 1600)
            } catch {
                // Preview failures should not interrupt normal file browsing.
            }
            if self.previewRequestID == requestID { self.isLoadingPreview = false }
        }
    }

    func loadThumbnail(for file: RemoteFile) {
        guard file.isImage, thumbnailImages[file.id] == nil,
              !loadingThumbnailIDs.contains(file.id), let device = selectedDevice else { return }
        loadingThumbnailIDs.insert(file.id)
        Task { [weak self] in
            guard let self else { return }
            let local = self.cachedImageURL(for: file, device: device)
            defer { self.loadingThumbnailIDs.remove(file.id) }
            do {
                try FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: local.path) {
                    try await self.service.pull(remote: file.path, local: local, device: device)
                }
                if let image = self.loadImage(at: local, maxPixelSize: 240) { self.thumbnailImages[file.id] = image }
            } catch {
                // A generic photo icon remains visible if thumbnail loading fails.
            }
        }
    }

    private func cachedImageURL(for file: RemoteFile, device: AndroidDevice) -> URL {
        let safeKey = Data(file.path.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("FileFlyferPreview", isDirectory: true)
            .appendingPathComponent(device.serial, isDirectory: true)
            .appendingPathComponent(safeKey + "." + NSString(string: file.name).pathExtension)
    }

    private func loadImage(at url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }

    func goUp() {
        let parent = NSString(string: currentPath).deletingLastPathComponent
        guard ShellEscaper.isAllowedSharedStoragePath(parent) else { return }
        navigate(to: parent)
    }

    func loadFiles() async {
        guard let device = selectedDevice, device.state == .device else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            files = try await service.list(path: currentPath, device: device)
            loadedLocationKey = "\(device.id):\(currentPath)"
            selectedFileIDs.removeAll()
        } catch { present(error) }
    }

    func upload(_ urls: [URL]) {
        guard let device = selectedDevice else { return }
        for url in urls {
            guard let remote = try? ShellEscaper.join(currentPath, url.lastPathComponent) else { continue }
            let item = TransferItem(source: url.path, destination: remote, fileName: url.lastPathComponent, direction: .upload)
            if files.contains(where: { $0.name == url.lastPathComponent }) { pendingConflicts.append(.init(item: item)) }
            else { transfers.append(item) }
        }
        showNextConflict()
        processQueue(device: device)
    }

    func downloadSelected(to directory: URL) {
        guard let device = selectedDevice else { return }
        for file in selectedFiles where !file.isDirectory {
            let local = directory.appendingPathComponent(file.name)
            let item = TransferItem(source: file.path, destination: local.path, fileName: file.name, direction: .download)
            if FileManager.default.fileExists(atPath: local.path) { pendingConflicts.append(.init(item: item)) }
            else { transfers.append(item) }
        }
        showNextConflict()
        processQueue(device: device)
    }

    func resolveConflict(overwrite: Bool, useNewName: Bool = false) {
        guard let conflict else { return }
        var item = conflict.item
        if overwrite {
            transfers.append(item)
        } else if useNewName {
            item = uniqueCopy(of: item)
            transfers.append(item)
        }
        self.conflict = nil
        showNextConflict()
        if let device = selectedDevice { processQueue(device: device) }
    }

    func cancelTransfer() {
        transferTask?.cancel()
        service.cancelCurrentOperation()
    }

    func createFolder(named name: String) async {
        guard let device = selectedDevice else { return }
        do { try await service.createDirectory(named: name, in: currentPath, device: device); await loadFiles() }
        catch { present(error) }
    }

    func rename(_ file: RemoteFile, to name: String) async {
        guard let device = selectedDevice else { return }
        do { try await service.rename(path: file.path, to: name, device: device); await loadFiles() }
        catch { present(error) }
    }

    func delete(_ targets: [RemoteFile]) async {
        guard let device = selectedDevice else { return }
        do {
            for target in targets { try await service.delete(path: target.path, device: device) }
            await loadFiles()
        } catch { present(error) }
    }

    private func processQueue(device: AndroidDevice) {
        guard transferTask == nil else { return }
        transferTask = Task { [weak self] in
            guard let self else { return }
            while let index = self.transfers.firstIndex(where: { $0.status == .waiting }) {
                self.transfers[index].status = .running
                self.transfers[index].startedAt = Date()
                do {
                    let item = self.transfers[index]
                    if item.direction == .upload {
                        try await self.service.push(local: URL(fileURLWithPath: item.source), remote: item.destination, device: device)
                    } else {
                        try await self.service.pull(remote: item.source, local: URL(fileURLWithPath: item.destination), device: device)
                    }
                    self.transfers[index].status = .completed
                } catch is CancellationError {
                    self.transfers[index].status = .cancelled
                } catch {
                    let appError = error as? AppError ?? .commandFailed(error.localizedDescription)
                    self.transfers[index].status = appError == .cancelled ? .cancelled : .failed
                    self.transfers[index].errorMessage = appError.localizedDescription
                }
            }
            self.transferTask = nil
            await self.loadFiles()
        }
    }

    private func present(_ source: Error) {
        let mapped = source as? AppError ?? .commandFailed(source.localizedDescription)
        error = mapped
        technicalError = source.localizedDescription
    }

    private func showNextConflict() {
        guard conflict == nil, !pendingConflicts.isEmpty else { return }
        conflict = pendingConflicts.removeFirst()
    }

    private func uniqueCopy(of item: TransferItem) -> TransferItem {
        let ext = NSString(string: item.fileName).pathExtension
        let stem = NSString(string: item.fileName).deletingPathExtension
        let copyName = ext.isEmpty ? "\(stem) kopya" : "\(stem) kopya.\(ext)"
        let destination: String
        if item.direction == .upload {
            destination = NSString(string: item.destination).deletingLastPathComponent + "/" + copyName
        } else {
            destination = URL(fileURLWithPath: item.destination).deletingLastPathComponent().appendingPathComponent(copyName).path
        }
        return TransferItem(source: item.source, destination: destination, fileName: copyName, direction: item.direction)
    }
}
