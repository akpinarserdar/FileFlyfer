import XCTest
@testable import FileFlyfer

final class ShellEscaperTests: XCTestCase {
    func testSingleQuoteEscaping() {
        XCTAssertEqual(ShellEscaper.quote("Ali'nin dosyası"), "'Ali'\\''nin dosyası'")
    }

    func testSharedStorageBoundary() {
        XCTAssertTrue(ShellEscaper.isAllowedSharedStoragePath("/sdcard/Download/çocuk.txt"))
        XCTAssertTrue(ShellEscaper.isAllowedSharedStoragePath("/storage/emulated/0/DCIM"))
        XCTAssertFalse(ShellEscaper.isAllowedSharedStoragePath("/sdcard-other/file"))
        XCTAssertFalse(ShellEscaper.isAllowedSharedStoragePath("/data/data/app"))
    }

    func testJoinRejectsTraversalAndSeparators() {
        XCTAssertThrowsError(try ShellEscaper.join("/sdcard/Download", "../secret"))
        XCTAssertThrowsError(try ShellEscaper.join("/sdcard/Download", "a/b"))
        XCTAssertEqual(try ShellEscaper.join("/sdcard/Download", "Türkçe ' dosya.txt"), "/sdcard/Download/Türkçe ' dosya.txt")
    }
}
