import XCTest
@testable import HotkeySpyCore

final class EventBuilderTests: XCTestCase {
    let t = Date(timeIntervalSince1970: 0)

    func testRejectsWhenNoRealModifier() {
        let e = EventBuilder.make(keycode: 21, mods: [.shift], sourcePID: 0,
                                  frontmostApp: nil, timestamp: t, appName: { _ in nil })
        XCTAssertNil(e)
    }
    func testHardwareWhenPidZero() {
        let e = EventBuilder.make(keycode: 21, mods: [.command, .shift], sourcePID: 0,
                                  frontmostApp: "Finder", timestamp: t, appName: { _ in nil })
        XCTAssertEqual(e?.combo, "⇧⌘4")
        XCTAssertEqual(e?.source, .hardware)
        XCTAssertEqual(e?.frontmostApp, "Finder")
    }
    func testSyntheticWhenPidResolves() {
        let e = EventBuilder.make(keycode: 21, mods: [.command, .shift], sourcePID: 999,
                                  frontmostApp: nil, timestamp: t,
                                  appName: { $0 == 999 ? "SneakyApp" : nil })
        XCTAssertEqual(e?.source, .synthetic(app: "SneakyApp"))
    }
    func testUnknownWhenPidUnresolved() {
        let e = EventBuilder.make(keycode: 21, mods: [.command], sourcePID: 777,
                                  frontmostApp: nil, timestamp: t, appName: { _ in nil })
        XCTAssertEqual(e?.source, .unknown(pid: 777))
    }
}
