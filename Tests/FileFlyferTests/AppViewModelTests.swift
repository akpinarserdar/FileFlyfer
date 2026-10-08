import XCTest
@testable import FileFlyfer

final class AppViewModelTests: XCTestCase {
    @MainActor
    func testUnauthorizedDeviceDoesNotListStorage() async {
        let service = FakeADBService(devices: [AndroidDevice(serial: "1", state: .unauthorized)])
        let model = AppViewModel(service: service)
        await model.refreshDevices()
        XCTAssertEqual(model.selectedDevice?.state, .unauthorized)
        XCTAssertTrue(model.files.isEmpty)
        XCTAssertEqual(service.listCallCount, 0)
    }

    @MainActor
    func testSilentRefreshDoesNotPresentPollingError() async {
        let service = FakeADBService(devices: [], devicesError: .adbUnavailable)
        let model = AppViewModel(service: service)

        await model.refreshDevices(silent: true)

        XCTAssertNil(model.error)
    }

    @MainActor
    func testUserRefreshPresentsADBError() async {
        let service = FakeADBService(devices: [], devicesError: .adbUnavailable)
        let model = AppViewModel(service: service)

        await model.refreshDevices()

        XCTAssertEqual(model.error, .adbUnavailable)
    }

    @MainActor
    func testSilentPollingDoesNotReloadAnEmptyFolder() async {
        let service = FakeADBService(devices: [AndroidDevice(serial: "1", state: .device)])
        let model = AppViewModel(service: service)

        await model.refreshDevices()
        await model.refreshDevices(silent: true)

        XCTAssertEqual(service.listCallCount, 1)
    }
}

final class FakeADBService: ADBServicing, @unchecked Sendable {
    let suppliedDevices: [AndroidDevice]
    let devicesError: AppError?
    private(set) var listCallCount = 0
    init(devices: [AndroidDevice], devicesError: AppError? = nil) {
        suppliedDevices = devices
        self.devicesError = devicesError
    }
    func devices() async throws -> [AndroidDevice] {
        if let devicesError { throw devicesError }
        return suppliedDevices
    }
    func deviceDetails(for device: AndroidDevice) async throws -> AndroidDevice { device }
    func list(path: String, device: AndroidDevice) async throws -> [RemoteFile] { listCallCount += 1; return [] }
    func push(local: URL, remote: String, device: AndroidDevice) async throws {}
    func pull(remote: String, local: URL, device: AndroidDevice) async throws {}
    func createDirectory(named name: String, in parent: String, device: AndroidDevice) async throws {}
    func rename(path: String, to newName: String, device: AndroidDevice) async throws {}
    func delete(path: String, device: AndroidDevice) async throws {}
    func cancelCurrentOperation() {}
}
