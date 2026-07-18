import XCTest
@testable import HotkeySpyCore

final class KeyFilterTests: XCTestCase {
    func testNoModifiersRejected() {
        XCTAssertFalse(KeyFilter.shouldCapture([]))
    }
    func testShiftAloneRejected() {
        XCTAssertFalse(KeyFilter.shouldCapture([.shift]))
    }
    func testCommandCaptured() {
        XCTAssertTrue(KeyFilter.shouldCapture([.command]))
    }
    func testControlCaptured() {
        XCTAssertTrue(KeyFilter.shouldCapture([.control]))
    }
    func testOptionCaptured() {
        XCTAssertTrue(KeyFilter.shouldCapture([.option]))
    }
    func testCommandShiftCaptured() {
        XCTAssertTrue(KeyFilter.shouldCapture([.command, .shift]))
    }
}
