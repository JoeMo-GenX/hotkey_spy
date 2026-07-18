import XCTest
@testable import HotkeySpyCore

final class EventLogTests: XCTestCase {
    private func event(_ combo: String) -> KeyEvent {
        KeyEvent(combo: combo, source: .hardware, frontmostApp: nil,
                 timestamp: Date(timeIntervalSince1970: 0))
    }

    func testNewestFirst() {
        let log = EventLog()
        log.add(event("⌘A"))
        log.add(event("⌘B"))
        XCTAssertEqual(log.events.map(\.combo), ["⌘B", "⌘A"])
    }
    func testBoundedToLimit() {
        let log = EventLog(limit: 2)
        log.add(event("⌘A"))
        log.add(event("⌘B"))
        log.add(event("⌘C"))
        XCTAssertEqual(log.events.map(\.combo), ["⌘C", "⌘B"])
    }
    func testClear() {
        let log = EventLog()
        log.add(event("⌘A"))
        log.clear()
        XCTAssertTrue(log.events.isEmpty)
    }
}
