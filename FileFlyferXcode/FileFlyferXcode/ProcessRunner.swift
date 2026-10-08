import Foundation

protocol ProcessRunning: Sendable {
    func run(executable: URL, arguments: [String], timeout: Duration?) async throws -> CommandResult
    func cancelCurrent()
}

final class ProcessRunner: ProcessRunning, @unchecked Sendable {
    private final class DataCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()
        func append(_ data: Data) { lock.withLock { storage.append(data) } }
        var data: Data { lock.withLock { storage } }
    }

    private let lock = NSLock()
    private var processes: [UUID: Process] = [:]
    private var cancelledIDs = Set<UUID>()

    func run(executable: URL, arguments: [String], timeout: Duration? = .seconds(30)) async throws -> CommandResult {
        let process = Process()
        let operationID = UUID()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        // Keep ADB's RSA identity inside the app container. Relying on ~/.android
        // makes a sandboxed/TestFlight build ask for access repeatedly and makes
        // the bundled ADB dependent on tools installed on the current Mac.
        if let adbHome = try? Self.adbHomeDirectory() {
            environment["HOME"] = adbHome.path
            environment["ANDROID_USER_HOME"] = adbHome.appendingPathComponent(".android", isDirectory: true).path
        }
        // A TestFlight/App Store build is sandboxed. Give its private ADB server
        // a socket inside the app container so it can start without binding a
        // global localhost port. Unsandboxed debug builds can reuse the user's
        // normal terminal ADB daemon.
        if environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            let socketPath = FileManager.default.temporaryDirectory
                .appendingPathComponent("fileflyfer-adb.sock", isDirectory: false).path
            environment["ADB_SERVER_SOCKET"] = "localfilesystem:\(socketPath)"
        } else {
            environment["ADB_SERVER_SOCKET"] = "tcp:127.0.0.1:5037"
        }
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let outputCollector = DataCollector()
        let errorCollector = DataCollector()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputCollector.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorCollector.append(handle.availableData)
        }

        lock.withLock {
            processes[operationID] = process
            cancelledIDs.remove(operationID)
        }

        do { try process.run() } catch {
            lock.withLock { processes[operationID] = nil }
            throw AppError.adbUnavailable
        }

        let didTimeOut = await wait(for: process, operationID: operationID, timeout: timeout)
        let wasCancelled = lock.withLock { cancelledIDs.contains(operationID) }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        outputCollector.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        errorCollector.append(errorPipe.fileHandleForReading.readDataToEndOfFile())
        lock.withLock {
            processes[operationID] = nil
            cancelledIDs.remove(operationID)
        }
        return CommandResult(
            standardOutput: outputCollector.data, standardError: errorCollector.data, exitCode: process.terminationStatus,
            wasCancelled: wasCancelled, timedOut: didTimeOut
        )
    }

    private static func adbHomeDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let home = base.appendingPathComponent("FileFlyfer/ADBHome", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".android", isDirectory: true),
            withIntermediateDirectories: true
        )
        return home
    }

    func cancelCurrent() {
        lock.withLock {
            cancelledIDs.formUnion(processes.keys)
            for process in processes.values { process.terminate() }
        }
    }

    private func wait(for process: Process, operationID: UUID, timeout: Duration?) async -> Bool {
        let clock = ContinuousClock()
        let deadline = timeout.map { clock.now.advanced(by: $0) }
        while process.isRunning {
            if Task.isCancelled {
                lock.withLock { cancelledIDs.insert(operationID) }
                process.terminate()
                return false
            }
            if let deadline, clock.now >= deadline {
                process.terminate()
                return true
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}
