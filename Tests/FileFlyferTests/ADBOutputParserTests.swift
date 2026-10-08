import XCTest
@testable import FileFlyfer

final class ADBOutputParserTests: XCTestCase {
    func testParsesConnectedUnauthorizedAndOfflineDevices() {
        let output = """
        List of devices attached
        ABC123 device product:foo model:Pixel_8 device:shiba transport_id:1
        TURKÇE unauthorized usb:1-2 transport_id:2
        OLD offline transport_id:3

        """
        let devices = ADBOutputParser.devices(output)
        XCTAssertEqual(devices.count, 3)
        XCTAssertEqual(devices[0].serial, "ABC123")
        XCTAssertEqual(devices[0].model, "Pixel_8")
        XCTAssertEqual(devices[0].state, .device)
        XCTAssertEqual(devices[1].state, .unauthorized)
        XCTAssertEqual(devices[2].state, .offline)
    }

    func testParsesUnicodeRemoteFileNames() throws {
        let name = "Çocuk fotoğrafı 'özel'.jpg"
        let encoded = try XCTUnwrap(name.data(using: .utf8)?.base64EncodedString())
        let files = ADBOutputParser.remoteFiles("\(encoded)\tf\t2048\t1700000000\n", parent: "/sdcard/Download")
        XCTAssertEqual(files.first?.name, name)
        XCTAssertEqual(files.first?.size, 2048)
        XCTAssertEqual(files.first?.path, "/sdcard/Download/\(name)")
    }

    func testDirectoriesSortBeforeFiles() {
        let file = Data("a.txt".utf8).base64EncodedString()
        let folder = Data("Z klasör".utf8).base64EncodedString()
        let files = ADBOutputParser.remoteFiles("\(file)\tf\t1\t1\n\(folder)\td\t0\t1\n", parent: "/sdcard")
        XCTAssertEqual(files.map(\.name), ["Z klasör", "a.txt"])
    }
}
