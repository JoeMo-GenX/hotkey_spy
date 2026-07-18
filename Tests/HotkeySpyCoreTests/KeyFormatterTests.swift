import XCTest
@testable import HotkeySpyCore

final class KeyFormatterTests: XCTestCase {
    func testSymbolOrderIsControlOptionShiftCommand() {
        XCTAssertEqual(KeyFormatter.symbols(for: [.command, .control, .option, .shift]), "⌃⌥⇧⌘")
    }
    func testScreenshotCombo() {
        // keycode 21 == "4"; Command+Shift => ⇧⌘4
        XCTAssertEqual(KeyFormatter.combo(keycode: 21, mods: [.command, .shift]), "⇧⌘4")
    }
    func testKnownLetterKeycode() {
        XCTAssertEqual(KeyFormatter.keyName(for: 0), "A")
    }
    func testSpaceKeycode() {
        XCTAssertEqual(KeyFormatter.keyName(for: 49), "Space")
    }
    func testUnknownKeycodeFallback() {
        XCTAssertEqual(KeyFormatter.keyName(for: 999), "key#999")
    }
}
