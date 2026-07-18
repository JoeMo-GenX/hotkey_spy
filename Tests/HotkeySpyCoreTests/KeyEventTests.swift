import XCTest
@testable import HotkeySpyCore

final class KeyEventTests: XCTestCase {
    func testHardwareSourceLabelAndSuspicion() {
        let s = EventSource.hardware
        XCTAssertEqual(s.label, "Physical keyboard")
        XCTAssertFalse(s.isSuspicious)
    }
    func testSyntheticSourceLabelAndSuspicion() {
        let s = EventSource.synthetic(app: "Terminal")
        XCTAssertEqual(s.label, "Synthetic — Terminal")
        XCTAssertTrue(s.isSuspicious)
    }
    func testUnknownSourceLabelAndSuspicion() {
        let s = EventSource.unknown(pid: 4321)
        XCTAssertEqual(s.label, "Synthetic — pid 4321")
        XCTAssertTrue(s.isSuspicious)
    }
    func testEventEquatable() {
        let id = UUID()
        let t = Date(timeIntervalSince1970: 0)
        let a = KeyEvent(id: id, combo: "⌘A", source: .hardware, frontmostApp: "X", timestamp: t)
        let b = KeyEvent(id: id, combo: "⌘A", source: .hardware, frontmostApp: "X", timestamp: t)
        XCTAssertEqual(a, b)
    }
}
