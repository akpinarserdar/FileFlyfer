import Foundation

protocol ADBServicing: Sendable {
    func devices() async throws -> [AndroidDevice]
    func deviceDetails(for device: AndroidDevice) async throws -> AndroidDevice
    func list(path: String, device: AndroidDevice) async throws -> [RemoteFile]
    func push(local: URL, remote: String, device: AndroidDevice) async throws
    func pull(remote: String, local: URL, device: AndroidDevice) async throws
    func createDirectory(named name: String, in parent: String, device: AndroidDevice) async throws
    func rename(path: String, to newName: String, device: AndroidDevice) async throws
    func delete(path: String, device: AndroidDevice) async throws
    func cancelCurrentOperation()
}

final class ADBService: ADBServicing, @unchecked Sendable {
    private let runner: ProcessRunning
    private let executable: URL

    init(runner: ProcessRunning = ProcessRunner(), executable: URL? = nil) {
        self.runner = runner
        self.executable = executable ?? Self.locateADB()
    }

    func devices() async throws -> [AndroidDevice] {
        let result = try await execute(["devices", "-l"])
        return ADBOutputParser.devices(result.outputString)
    }

    func deviceDetails(for device: AndroidDevice) async throws -> AndroidDevice {
        try ensureAuthorized(device)
        async let brand = property("ro.product.brand", device: device)
        async let manufacturer = property("ro.product.manufacturer", device: device)
        async let marketName = property("ro.product.marketname", device: device)
        async let model = property("ro.product.model", device: device)
        async let name = property("ro.product.device", device: device)
        async let version = property("ro.build.version.release", device: device)
        async let sdk = property("ro.build.version.sdk", device: device)
        async let securityPatch = property("ro.build.version.security_patch", device: device)
        async let buildID = property("ro.build.id", device: device)
        async let lineage = property("ro.lineage.version", device: device)
        async let storage = storageInfo(device: device)
        async let battery = batteryInfo(device: device)
        var detailed = device
        detailed.brand = try await brand
        detailed.manufacturer = try await manufacturer
        detailed.marketName = try await marketName
        detailed.model = try await model
        detailed.deviceName = try await name
        detailed.androidVersion = try await version
        detailed.sdkVersion = try await sdk
        detailed.securityPatch = try await securityPatch
        detailed.buildID = try await buildID
        detailed.lineageVersion = try await lineage
        let storageValues = try await storage
        detailed.storageTotalBytes = storageValues.total
        detailed.storageFreeBytes = storageValues.free
        let batteryValues = try await battery
        detailed.batteryLevel = batteryValues.level
        detailed.batteryCharging = batteryValues.charging
        return detailed
    }

    func list(path: String, device: AndroidDevice) async throws -> [RemoteFile] {
        try validate(path, device: device)
        let script = #"for item in "$1"/* "$1"/.[!.]* "$1"/..?*; do [ -e "$item" ] || continue; name=$(printf '%s' "$(basename "$item")" | base64 | tr -d '\n'); kind=$(stat -c '%F' "$item"); case "$kind" in directory) type=d;; "regular file") type=f;; "symbolic link") type=l;; *) type=o;; esac; size=$(stat -c '%s' "$item" 2>/dev/null || echo 0); time=$(stat -c '%Y' "$item" 2>/dev/null || echo 0); printf '%s\t%s\t%s\t%s\n' "$name" "$type" "$size" "$time"; done"#
        let result = try await execute(target(device, shellScript(script, arguments: [path])))
        return ADBOutputParser.remoteFiles(result.outputString, parent: path)
    }

    func push(local: URL, remote: String, device: AndroidDevice) async throws {
        try validate(remote, device: device)
        _ = try await execute(target(device, ["push", local.path, remote]), timeout: .seconds(3_600))
    }

    func pull(remote: String, local: URL, device: AndroidDevice) async throws {
        try validate(remote, device: device)
        _ = try await execute(target(device, ["pull", remote, local.path]), timeout: .seconds(3_600))
    }

    func createDirectory(named name: String, in parent: String, device: AndroidDevice) async throws {
        let path = try ShellEscaper.join(parent, name)
        try validate(path, device: device)
        _ = try await execute(target(device, shellScript("mkdir -- \"$1\"", arguments: [path])))
    }

    func rename(path: String, to newName: String, device: AndroidDevice) async throws {
        try validate(path, device: device)
        let destination = try ShellEscaper.join(NSString(string: path).deletingLastPathComponent, newName)
        _ = try await execute(target(device, shellScript("mv -- \"$1\" \"$2\"", arguments: [path, destination])))
    }

    func delete(path: String, device: AndroidDevice) async throws {
        try validate(path, device: device)
        guard path != "/sdcard", path != "/storage/emulated/0" else { throw AppError.unsafePath }
        _ = try await execute(target(device, shellScript("rm -rf -- \"$1\"", arguments: [path])))
    }

    func cancelCurrentOperation() { runner.cancelCurrent() }

    private func property(_ name: String, device: AndroidDevice) async throws -> String {
        let result = try await execute(target(device, ["shell", "getprop", name]))
        return result.outputString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func storageInfo(device: AndroidDevice) async throws -> (total: Int64?, free: Int64?) {
        let result = try await execute(target(device, ["shell", "df", "-k", "/sdcard"]))
        guard let line = result.outputString.split(whereSeparator: \.isNewline).last else { return (nil, nil) }
        let fields = line.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 4,
              let total = Int64(fields[1]), let available = Int64(fields[3]) else { return (nil, nil) }
        return (total * 1024, available * 1024)
    }

    private func batteryInfo(device: AndroidDevice) async throws -> (level: Int?, charging: Bool?) {
        let result = try await execute(target(device, ["shell", "dumpsys", "battery"]))
        var level: Int?
        var charging: Bool?
        for line in result.outputString.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "level" { level = Int(value) }
            if ["AC powered", "USB powered", "Wireless powered", "Dock powered"].contains(key), value == "true" {
                charging = true
            }
        }
        return (level, charging ?? false)
    }

    private func target(_ device: AndroidDevice, _ arguments: [String]) -> [String] {
        ["-s", device.serial] + arguments
    }

    private func shellScript(_ script: String, arguments: [String]) -> [String] {
        // `adb shell` joins its trailing arguments into a remote command line. Quote each
        // remote token here; local Process arguments remain separate and never invoke a shell.
        ["shell", "sh", "-c", ShellEscaper.quote(script), "sh"] + arguments.map(ShellEscaper.quote)
    }

    private func validate(_ path: String, device: AndroidDevice) throws {
        try ensureAuthorized(device)
        guard ShellEscaper.isAllowedSharedStoragePath(path) else { throw AppError.unsafePath }
    }

    private func ensureAuthorized(_ device: AndroidDevice) throws {
        switch device.state {
        case .device: break
        case .unauthorized: throw AppError.unauthorized
        case .offline: throw AppError.offline
        case .unknown: throw AppError.noDevice
        }
    }

    private func execute(_ arguments: [String], timeout: Duration? = .seconds(30)) async throws -> CommandResult {
        let result = try await runner.run(executable: executable, arguments: arguments, timeout: timeout)
        if result.wasCancelled { throw AppError.cancelled }
        if result.timedOut { throw AppError.timedOut }
        guard result.exitCode == 0 else { throw mapError(result.errorString + result.outputString) }
        return result
    }

    private func mapError(_ raw: String) -> AppError {
        let text = raw.lowercased()
        if text.contains("unauthorized") { return .unauthorized }
        if text.contains("offline") { return .offline }
        if text.contains("no devices") || text.contains("device not found") { return .noDevice }
        if text.contains("closed") || text.contains("disconnected") { return .disconnected }
        if text.contains("no space left") { return .insufficientStorage }
        if text.contains("daemon not running") || text.contains("failed to start daemon") ||
            text.contains("daemon didn't ack") || text.contains("server didn't ack") ||
            text.contains("could not install *smartsocket* listener") ||
            text.contains("failed to check server version") || text.contains("operation not permitted") ||
            text.contains("cannot connect to daemon") {
            return .adbUnavailable
        }
        if text.contains("permission denied") || text.contains("read-only") { return .notWritable }
        if text.contains("no such file") { return .notFound }
        if text.contains("file exists") { return .alreadyExists }
        let detail = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return .commandFailed(detail.isEmpty ? String(localized: "Bilinmeyen ADB hatası") : detail)
    }

    static func locateADB() -> URL {
        if let bundled = Bundle.main.url(forResource: "adb", withExtension: nil) { return bundled }
        if let configured = ProcessInfo.processInfo.environment["ADB_PATH"], !configured.isEmpty {
            return URL(fileURLWithPath: configured)
        }
        let candidates = [
            "/opt/homebrew/bin/adb", "/usr/local/bin/adb",
            NSString(string: "~/Library/Android/sdk/platform-tools/adb").expandingTildeInPath
        ]
        return URL(fileURLWithPath: candidates.first(where: FileManager.default.isExecutableFile(atPath:)) ?? "/usr/bin/adb")
    }
}
