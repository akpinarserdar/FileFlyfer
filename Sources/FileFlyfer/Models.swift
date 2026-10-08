import Foundation

enum DeviceState: String, Sendable, Codable {
    case device
    case unauthorized
    case offline
    case unknown

    var title: String {
        switch self {
        case .device: String(localized: "Bağlı")
        case .unauthorized: String(localized: "Yetki bekleniyor")
        case .offline: String(localized: "Çevrimdışı")
        case .unknown: String(localized: "Bilinmeyen")
        }
    }
}

struct AndroidDevice: Identifiable, Hashable, Sendable {
    let serial: String
    var state: DeviceState
    var product: String?
    var brand: String?
    var manufacturer: String?
    var marketName: String?
    var model: String?
    var deviceName: String?
    var androidVersion: String?
    var sdkVersion: String?
    var securityPatch: String?
    var buildID: String?
    var lineageVersion: String?
    var storageTotalBytes: Int64?
    var storageFreeBytes: Int64?
    var batteryLevel: Int?
    var batteryCharging: Bool?

    var id: String { serial }
    var displayName: String { marketName ?? model?.replacingOccurrences(of: "_", with: " ") ?? deviceName ?? serial }
    /// Stable ADB identity first, with a human-readable brand/model suffix when available.
    var pickerName: String {
        let identity = marketName ?? model?.replacingOccurrences(of: "_", with: " ") ?? deviceName
        let readable = [brand, manufacturer, identity]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .reduce(into: [String]()) { result, value in
                if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                    result.append(value)
                }
            }
            .joined(separator: " ")
        return readable.isEmpty ? serial : "\(serial) — \(readable)"
    }
}

struct RemoteFile: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case directory = "d", file = "f", link = "l", other }

    let path: String
    let name: String
    let kind: Kind
    let size: Int64
    let modifiedAt: Date?

    var id: String { path }
    var isDirectory: Bool { kind == .directory }
    var isImage: Bool {
        ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp"]
            .contains(NSString(string: name).pathExtension.lowercased())
    }
}

enum TransferDirection: String, Sendable { case upload, download }
enum TransferStatus: String, Sendable { case waiting, running, completed, failed, cancelled }

struct TransferItem: Identifiable, Sendable {
    let id: UUID
    let source: String
    let destination: String
    let fileName: String
    let direction: TransferDirection
    var status: TransferStatus
    var startedAt: Date?
    var errorMessage: String?

    init(source: String, destination: String, fileName: String, direction: TransferDirection) {
        id = UUID()
        self.source = source
        self.destination = destination
        self.fileName = fileName
        self.direction = direction
        status = .waiting
    }
}

struct CommandResult: Sendable {
    let standardOutput: Data
    let standardError: Data
    let exitCode: Int32
    let wasCancelled: Bool
    let timedOut: Bool

    var outputString: String { String(decoding: standardOutput, as: UTF8.self) }
    var errorString: String { String(decoding: standardError, as: UTF8.self) }
}

enum AppError: LocalizedError, Sendable, Equatable {
    case noDevice, unauthorized, offline, disconnected, notWritable, notFound
    case insufficientStorage, alreadyExists, timedOut, adbUnavailable, cancelled
    case unsafePath, commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDevice: String(localized: "Cihaz bulunamadı.")
        case .unauthorized: String(localized: "Cihaz yetkilendirilmedi. Telefonda RSA iznini onaylayın.")
        case .offline: String(localized: "Cihaz çevrimdışı.")
        case .disconnected: String(localized: "Cihaz bağlantısı kesildi.")
        case .notWritable: String(localized: "Hedef klasöre yazılamıyor.")
        case .notFound: String(localized: "Dosya bulunamadı.")
        case .insufficientStorage: String(localized: "Cihazda yeterli depolama alanı yok.")
        case .alreadyExists: String(localized: "Aynı isimli bir dosya zaten var.")
        case .timedOut: String(localized: "İşlem zaman aşımına uğradı.")
        case .adbUnavailable: String(localized: "ADB çalıştırılamadı.")
        case .cancelled: String(localized: "Aktarım iptal edildi.")
        case .unsafePath: String(localized: "Bu konuma erişime izin verilmiyor.")
        case let .commandFailed(message): String(localized: "İşlem tamamlanamadı: \(message)")
        }
    }
}
