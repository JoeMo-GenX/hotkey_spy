# hotkey-spy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu-bar app that detects modifier-combo key-downs and reports whether each came from a real keyboard or a synthetic (software-posted) source, to diagnose ghost hotkey presses.

**Architecture:** A Swift Package with two targets — `HotkeySpyCore` (pure, unit-tested logic: filtering, formatting, models, log) and `HotkeySpy` (SwiftUI `MenuBarExtra` executable holding the AppKit/CoreGraphics glue: `CGEventTap`, permissions, notifications, UI). The event tap observes key-downs (`.listenOnly`, never consuming them), the pure `EventBuilder` turns raw fields into a `KeyEvent`, and that flows into an observable `EventLog` (drives the menu) and a `Notifier` (on-screen popup).

**Tech Stack:** Swift 5.9, SwiftUI `MenuBarExtra` (macOS 13+), Core Graphics `CGEventTap`, ApplicationServices (Accessibility), UserNotifications, AppKit.

## Global Constraints

- **Platform floor:** macOS 13 Ventura (`platforms: [.macOS(.v13)]`). `MenuBarExtra` requires it.
- **Capture rule (verbatim):** log a `.keyDown` only if its flags contain **⌘ Command, ⌃ Control, or ⌥ Option** (any combination). Shift alone never triggers; Shift may ride along in a real combo.
- **Listen-only:** the event tap must use `.listenOnly` and must never consume, block, or alter events.
- **No file logging.** In-memory log only, newest-first, bounded to 100 events, cleared on quit.
- **Naming:** git repo `hotkey_spy`; Swift package / product / bundle name `HotkeySpy`; bundle id `com.joemo.hotkeyspy`.
- **Repo:** https://github.com/JoeMo-GenX/hotkey_spy (public; `gh` authenticated as `JoeMo-GenX`).
- **Distribution:** unsigned `.app` in a GitHub Release; source builds with `swift build` and opens in Xcode.
- **Modifier symbol order (display):** `⌃⌥⇧⌘` then the key.

---

### Task 1: Package scaffold + reconcile with GitHub repo

**Files:**
- Create: `Package.swift`
- Create: `Sources/HotkeySpyCore/Placeholder.swift`
- Create: `Sources/HotkeySpy/main.swift` (temporary; replaced by the SwiftUI app in Task 9)
- Create: `Tests/HotkeySpyCoreTests/PlaceholderTests.swift`

**Interfaces:**
- Produces: package targets `HotkeySpyCore` (library), `HotkeySpy` (executable), `HotkeySpyCoreTests`.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HotkeySpy",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HotkeySpyCore"),
        .executableTarget(
            name: "HotkeySpy",
            dependencies: ["HotkeySpyCore"]
        ),
        .testTarget(
            name: "HotkeySpyCoreTests",
            dependencies: ["HotkeySpyCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create placeholder sources so the package compiles**

`Sources/HotkeySpyCore/Placeholder.swift`:
```swift
enum HotkeySpyCorePlaceholder {}
```

`Sources/HotkeySpy/main.swift`:
```swift
print("HotkeySpy placeholder — replaced by the SwiftUI app in Task 9.")
```

`Tests/HotkeySpyCoreTests/PlaceholderTests.swift`:
```swift
import XCTest
@testable import HotkeySpyCore

final class PlaceholderTests: XCTestCase {
    func testPackageBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 3: Verify it builds and tests run**

Run: `swift build && swift test`
Expected: build succeeds; `PlaceholderTests.testPackageBuilds` PASSES.

- [ ] **Step 4: Reconcile local history with the existing GitHub repo**

The local repo already has commits (the spec/plan); the GitHub repo has its own initial commit. Merge the unrelated histories.

Run:
```bash
git branch -M main
git remote add origin https://github.com/JoeMo-GenX/hotkey_spy.git 2>/dev/null || git remote set-url origin https://github.com/JoeMo-GenX/hotkey_spy.git
git fetch origin
git merge origin/main --allow-unrelated-histories -m "Merge existing GitHub repo history"
```
Expected: a merge commit; no conflicts (or resolve any README/LICENSE conflict by keeping both).

- [ ] **Step 5: Commit and push**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold HotkeySpy Swift package"
git push -u origin main
```
Expected: push succeeds; `Package.swift` visible at the repo URL.

---

### Task 2: `Modifiers` + `KeyFilter` (the capture rule)

**Files:**
- Create: `Sources/HotkeySpyCore/Modifiers.swift`
- Create: `Sources/HotkeySpyCore/KeyFilter.swift`
- Test: `Tests/HotkeySpyCoreTests/KeyFilterTests.swift`

**Interfaces:**
- Produces:
  - `public struct Modifiers: OptionSet { rawValue: Int; .command, .control, .option, .shift }`
  - `public enum KeyFilter { static func shouldCapture(_ mods: Modifiers) -> Bool }`

- [ ] **Step 1: Write the failing test**

`Tests/HotkeySpyCoreTests/KeyFilterTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeyFilterTests`
Expected: FAIL — `Modifiers` / `KeyFilter` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/HotkeySpyCore/Modifiers.swift`:
```swift
public struct Modifiers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let control = Modifiers(rawValue: 1 << 1)
    public static let option  = Modifiers(rawValue: 1 << 2)
    public static let shift   = Modifiers(rawValue: 1 << 3)
}
```

`Sources/HotkeySpyCore/KeyFilter.swift`:
```swift
public enum KeyFilter {
    /// A "real" modifier is Command, Control, or Option. Shift alone does not qualify.
    public static func shouldCapture(_ mods: Modifiers) -> Bool {
        mods.contains(.command) || mods.contains(.control) || mods.contains(.option)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeyFilterTests`
Expected: all 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/Modifiers.swift Sources/HotkeySpyCore/KeyFilter.swift Tests/HotkeySpyCoreTests/KeyFilterTests.swift
git commit -m "feat: modifier capture rule (command/control/option, not shift-alone)"
```

---

### Task 3: `KeyFormatter` (keycode + modifiers → combo string)

**Files:**
- Create: `Sources/HotkeySpyCore/KeyFormatter.swift`
- Test: `Tests/HotkeySpyCoreTests/KeyFormatterTests.swift`

**Interfaces:**
- Consumes: `Modifiers` (Task 2)
- Produces: `public enum KeyFormatter { static func symbols(for:) -> String; static func keyName(for:) -> String; static func combo(keycode:mods:) -> String }`

- [ ] **Step 1: Write the failing test**

`Tests/HotkeySpyCoreTests/KeyFormatterTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeyFormatterTests`
Expected: FAIL — `KeyFormatter` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/HotkeySpyCore/KeyFormatter.swift`:
```swift
public enum KeyFormatter {
    /// Modifier glyphs in canonical macOS order: ⌃⌥⇧⌘.
    public static func symbols(for mods: Modifiers) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s
    }

    public static func keyName(for keycode: Int) -> String {
        keycodeMap[keycode] ?? "key#\(keycode)"
    }

    public static func combo(keycode: Int, mods: Modifiers) -> String {
        symbols(for: mods) + keyName(for: keycode)
    }

    /// ANSI virtual keycodes → human labels (common subset).
    static let keycodeMap: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeyFormatterTests`
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/KeyFormatter.swift Tests/HotkeySpyCoreTests/KeyFormatterTests.swift
git commit -m "feat: keycode + modifier combo formatting"
```

---

### Task 4: `KeyEvent` model + `EventSource`

**Files:**
- Create: `Sources/HotkeySpyCore/KeyEvent.swift`
- Test: `Tests/HotkeySpyCoreTests/KeyEventTests.swift`

**Interfaces:**
- Produces:
  - `public enum EventSource: Equatable { case hardware; case synthetic(app: String); case unknown(pid: Int) }` with `var label: String` and `var isSuspicious: Bool`.
  - `public struct KeyEvent: Identifiable, Equatable { id: UUID; combo: String; source: EventSource; frontmostApp: String?; timestamp: Date }`

- [ ] **Step 1: Write the failing test**

`Tests/HotkeySpyCoreTests/KeyEventTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter KeyEventTests`
Expected: FAIL — `KeyEvent` / `EventSource` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/HotkeySpyCore/KeyEvent.swift`:
```swift
import Foundation

public enum EventSource: Equatable {
    case hardware
    case synthetic(app: String)
    case unknown(pid: Int)

    public var label: String {
        switch self {
        case .hardware:            return "Physical keyboard"
        case .synthetic(let app):  return "Synthetic — \(app)"
        case .unknown(let pid):    return "Synthetic — pid \(pid)"
        }
    }

    /// Anything not from the physical keyboard is a ghost-press suspect.
    public var isSuspicious: Bool {
        if case .hardware = self { return false }
        return true
    }
}

public struct KeyEvent: Identifiable, Equatable {
    public let id: UUID
    public let combo: String
    public let source: EventSource
    public let frontmostApp: String?
    public let timestamp: Date

    public init(id: UUID = UUID(), combo: String, source: EventSource,
                frontmostApp: String?, timestamp: Date) {
        self.id = id
        self.combo = combo
        self.source = source
        self.frontmostApp = frontmostApp
        self.timestamp = timestamp
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter KeyEventTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/KeyEvent.swift Tests/HotkeySpyCoreTests/KeyEventTests.swift
git commit -m "feat: KeyEvent model and EventSource classification"
```

---

### Task 5: `EventBuilder` (raw fields → `KeyEvent?`)

**Files:**
- Create: `Sources/HotkeySpyCore/EventBuilder.swift`
- Test: `Tests/HotkeySpyCoreTests/EventBuilderTests.swift`

**Interfaces:**
- Consumes: `Modifiers`, `KeyFilter`, `KeyFormatter`, `KeyEvent`, `EventSource`.
- Produces:
```swift
public enum EventBuilder {
    static func make(keycode: Int, mods: Modifiers, sourcePID: Int,
                     frontmostApp: String?, timestamp: Date,
                     appName: (Int) -> String?) -> KeyEvent?
}
```
`appName` resolves a PID to a process name (injected so it's testable; the app passes an `NSRunningApplication` lookup). Returns `nil` when the capture rule rejects the combo.

- [ ] **Step 1: Write the failing test**

`Tests/HotkeySpyCoreTests/EventBuilderTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EventBuilderTests`
Expected: FAIL — `EventBuilder` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/HotkeySpyCore/EventBuilder.swift`:
```swift
import Foundation

public enum EventBuilder {
    public static func make(keycode: Int, mods: Modifiers, sourcePID: Int,
                            frontmostApp: String?, timestamp: Date,
                            appName: (Int) -> String?) -> KeyEvent? {
        guard KeyFilter.shouldCapture(mods) else { return nil }

        let source: EventSource
        if sourcePID == 0 {
            source = .hardware
        } else if let name = appName(sourcePID) {
            source = .synthetic(app: name)
        } else {
            source = .unknown(pid: sourcePID)
        }

        return KeyEvent(
            combo: KeyFormatter.combo(keycode: keycode, mods: mods),
            source: source,
            frontmostApp: frontmostApp,
            timestamp: timestamp
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter EventBuilderTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/EventBuilder.swift Tests/HotkeySpyCoreTests/EventBuilderTests.swift
git commit -m "feat: EventBuilder assembles KeyEvent from raw fields"
```

---

### Task 6: `EventLog` (observable bounded list)

**Files:**
- Create: `Sources/HotkeySpyCore/EventLog.swift`
- Test: `Tests/HotkeySpyCoreTests/EventLogTests.swift`

**Interfaces:**
- Consumes: `KeyEvent`.
- Produces: `public final class EventLog: ObservableObject { @Published var events: [KeyEvent]; init(limit: Int = 100); func add(_:); func clear() }` — newest first, bounded.

- [ ] **Step 1: Write the failing test**

`Tests/HotkeySpyCoreTests/EventLogTests.swift`:
```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EventLogTests`
Expected: FAIL — `EventLog` not defined.

- [ ] **Step 3: Write minimal implementation**

`Sources/HotkeySpyCore/EventLog.swift`:
```swift
import Foundation
import Combine

public final class EventLog: ObservableObject {
    @Published public private(set) var events: [KeyEvent] = []
    private let limit: Int

    public init(limit: Int = 100) { self.limit = limit }

    public func add(_ event: KeyEvent) {
        events.insert(event, at: 0)          // newest first
        if events.count > limit {
            events.removeLast(events.count - limit)
        }
    }

    public func clear() { events.removeAll() }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter EventLogTests`
Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/EventLog.swift Tests/HotkeySpyCoreTests/EventLogTests.swift
git commit -m "feat: bounded newest-first EventLog"
```

---

### Task 7: `Notifier` protocol + `ToastNotifier` (reliable on-screen popup)

**Files:**
- Create: `Sources/HotkeySpy/EventNotifier.swift`
- Create: `Sources/HotkeySpy/ToastNotifier.swift`

**Interfaces:**
- Consumes: `KeyEvent`, `EventSource.label`, `KeyFormatter` (from Core).
- Produces:
  - `protocol EventNotifier { func notify(_ event: KeyEvent) }`
  - `final class ToastNotifier: EventNotifier` — shows a borderless top-right panel that auto-dismisses after ~4s.
- Note: app-target UI code; not covered by `swift test`. Verified by running the app in Task 9.

- [ ] **Step 1: Create the protocol**

`Sources/HotkeySpy/EventNotifier.swift`:
```swift
import HotkeySpyCore

protocol EventNotifier {
    func notify(_ event: KeyEvent)
}

/// Shared one-line summary used by every notifier and the menu.
func summaryLine(for event: KeyEvent) -> String {
    "\(event.combo)  ·  \(event.source.label)"
}
```

- [ ] **Step 2: Implement `ToastNotifier`**

`Sources/HotkeySpy/ToastNotifier.swift`:
```swift
import AppKit
import HotkeySpyCore

/// A borderless, non-activating panel in the top-right corner that fades out.
final class ToastNotifier: EventNotifier {
    private var panel: NSPanel?

    func notify(_ event: KeyEvent) {
        DispatchQueue.main.async { self.show(summaryLine(for: event),
                                             suspicious: event.source.isSuspicious) }
    }

    private func show(_ text: String, suspicious: Bool) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let padding: CGFloat = 14
        let size = NSSize(width: label.frame.width + padding * 2,
                          height: label.frame.height + padding * 2)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.backgroundColor = (suspicious
            ? NSColor.systemRed.withAlphaComponent(0.55)
            : NSColor.black.withAlphaComponent(0.35)).cgColor
        label.frame.origin = NSPoint(x: padding, y: padding)
        bg.addSubview(label)
        panel.contentView = bg

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 20,
                                         y: visible.maxY - size.height - 20))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak panel] in
            panel?.orderOut(nil)
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build`
Expected: build succeeds (behavior is verified when the app runs in Task 9).

- [ ] **Step 4: Commit**

```bash
git add Sources/HotkeySpy/EventNotifier.swift Sources/HotkeySpy/ToastNotifier.swift
git commit -m "feat: EventNotifier protocol and ToastNotifier popup"
```

---

### Task 8: `SystemNotifier` (native notification, falls back to toast)

**Files:**
- Create: `Sources/HotkeySpy/SystemNotifier.swift`

**Interfaces:**
- Consumes: `EventNotifier`, `ToastNotifier`, `KeyEvent`.
- Produces: `final class SystemNotifier: EventNotifier` — requests notification authorization; posts via `UNUserNotificationCenter` when authorized, otherwise delegates to an injected fallback (`ToastNotifier`). Since unsigned builds often can't post system notifications, the fallback guarantees the user still sees a popup.

- [ ] **Step 1: Implement `SystemNotifier`**

`Sources/HotkeySpy/SystemNotifier.swift`:
```swift
import Foundation
import UserNotifications
import HotkeySpyCore

final class SystemNotifier: EventNotifier {
    private let fallback: EventNotifier
    private var authorized = false
    private var available = false

    init(fallback: EventNotifier) {
        self.fallback = fallback
        // UNUserNotificationCenter traps without a bundle; guard for `swift run`.
        guard Bundle.main.bundleIdentifier != nil else { return }
        available = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                self?.authorized = granted
            }
    }

    func notify(_ event: KeyEvent) {
        guard available, authorized else { fallback.notify(event); return }
        let content = UNMutableNotificationContent()
        content.title = event.source.isSuspicious ? "⚠️ Ghost-press suspect" : "Hotkey detected"
        content.body = summaryLine(for: event)
        let request = UNNotificationRequest(identifier: event.id.uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error != nil { self?.fallback.notify(event) }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/HotkeySpy/SystemNotifier.swift
git commit -m "feat: SystemNotifier with toast fallback for unsigned builds"
```

---

### Task 9: `PermissionManager` (Accessibility trust)

**Files:**
- Create: `Sources/HotkeySpy/PermissionManager.swift`

**Interfaces:**
- Produces: `final class PermissionManager: ObservableObject { @Published var isTrusted: Bool; func promptIfNeeded(); func openSettings(); func startPolling(onGranted:) }`
- Note: TCC-dependent; verified by running the app in Task 11.

- [ ] **Step 1: Implement `PermissionManager`**

`Sources/HotkeySpy/PermissionManager.swift`:
```swift
import AppKit
import Combine
import ApplicationServices

final class PermissionManager: ObservableObject {
    @Published var isTrusted: Bool = AXIsProcessTrusted()
    private var timer: Timer?

    /// Shows the system Accessibility prompt if not yet trusted.
    func promptIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(opts)
    }

    func openSettings() {
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Polls once per second until trust is granted, then calls onGranted once.
    func startPolling(onGranted: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted { self.isTrusted = trusted }
            if trusted { onGranted(); t.invalidate() }
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/HotkeySpy/PermissionManager.swift
git commit -m "feat: Accessibility PermissionManager with prompt and polling"
```

---

### Task 10: `EventMonitor` (the CGEventTap engine)

**Files:**
- Create: `Sources/HotkeySpy/EventMonitor.swift`

**Interfaces:**
- Consumes: `EventLog`, `EventNotifier`, `Modifiers`, `KeyFilter`, `EventBuilder`.
- Produces: `final class EventMonitor { init(log: EventLog, notifier: EventNotifier); @discardableResult func start() -> Bool; func stop() }` — creates a `.listenOnly` session tap, applies the capture rule, resolves the source PID via `NSRunningApplication`, and pushes results to the log + notifier on the main queue. Re-enables the tap if macOS disables it.
- Note: requires Accessibility permission and a live run loop; verified by running the app in Task 11.

- [ ] **Step 1: Implement `EventMonitor`**

`Sources/HotkeySpy/EventMonitor.swift`:
```swift
import AppKit
import CoreGraphics
import HotkeySpyCore

final class EventMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let log: EventLog
    private let notifier: EventNotifier

    init(log: EventLog, notifier: EventNotifier) {
        self.log = log
        self.notifier = notifier
    }

    /// Returns false if the tap can't be created (usually: no Accessibility permission yet).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // macOS disables taps that stall or on certain input — re-enable and move on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown else { return }

        let mods = Self.modifiers(from: event.flags)
        guard KeyFilter.shouldCapture(mods) else { return }

        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let pid = Int(event.getIntegerValueField(.eventSourceUnixProcessID))
        let frontmost = NSWorkspace.shared.frontmostApplication?.localizedName

        guard let keyEvent = EventBuilder.make(
            keycode: keycode, mods: mods, sourcePID: pid,
            frontmostApp: frontmost, timestamp: Date(),
            appName: { NSRunningApplication(processIdentifier: pid_t($0))?.localizedName }
        ) else { return }

        DispatchQueue.main.async {
            self.log.add(keyEvent)
            self.notifier.notify(keyEvent)
        }
    }

    static func modifiers(from flags: CGEventFlags) -> Modifiers {
        var m = Modifiers()
        if flags.contains(.maskCommand)   { m.insert(.command) }
        if flags.contains(.maskControl)   { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift)     { m.insert(.shift) }
        return m
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/HotkeySpy/EventMonitor.swift
git commit -m "feat: CGEventTap EventMonitor with tap re-enable and PID source resolution"
```

---

### Task 11: `MenuContentView` + `HotkeySpyApp` (wire it all together)

**Files:**
- Delete: `Sources/HotkeySpy/main.swift` (replaced by the SwiftUI `@main` app)
- Create: `Sources/HotkeySpy/HotkeySpyApp.swift`
- Create: `Sources/HotkeySpy/MenuContentView.swift`

**Interfaces:**
- Consumes: `EventLog`, `PermissionManager`, `EventMonitor`, `SystemNotifier`, `ToastNotifier`.
- Produces: the running menu-bar app.

- [ ] **Step 1: Remove the placeholder entry point**

```bash
git rm Sources/HotkeySpy/main.swift
```

- [ ] **Step 2: Create the app entry point + coordinator**

`Sources/HotkeySpy/HotkeySpyApp.swift`:
```swift
import SwiftUI
import AppKit
import HotkeySpyCore

@main
struct HotkeySpyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("HotkeySpy", systemImage: "eye.circle") {
            MenuContentView()
                .environmentObject(appDelegate.log)
                .environmentObject(appDelegate.permissions)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let log = EventLog()
    let permissions = PermissionManager()
    private var monitor: EventMonitor!
    private var notifier: EventNotifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // tray-only, no Dock icon

        notifier = SystemNotifier(fallback: ToastNotifier())
        monitor = EventMonitor(log: log, notifier: notifier)

        if permissions.isTrusted {
            monitor.start()
        } else {
            permissions.promptIfNeeded()
            permissions.startPolling { [weak self] in self?.monitor.start() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
    }
}
```

- [ ] **Step 3: Create the menu UI**

`Sources/HotkeySpy/MenuContentView.swift`:
```swift
import SwiftUI
import HotkeySpyCore

struct MenuContentView: View {
    @EnvironmentObject var log: EventLog
    @EnvironmentObject var permissions: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusLine
            Divider()
            if log.events.isEmpty {
                Text("No modifier-combo key presses yet.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(log.events) { event in
                            EventRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            Divider()
            HStack {
                Button("Clear log") { log.clear() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    @ViewBuilder private var statusLine: some View {
        if permissions.isTrusted {
            Label("Monitoring", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Grant Accessibility…") {
                    permissions.promptIfNeeded()
                    permissions.openSettings()
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: KeyEvent

    var body: some View {
        HStack(spacing: 8) {
            Text(event.combo)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 60, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.source.label)
                    .foregroundStyle(event.source.isSuspicious ? .red : .primary)
                if let front = event.frontmostApp {
                    Text("front: \(front)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp, style: .time)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 4: Build and run; verify end-to-end**

Run: `swift build && swift run HotkeySpy`
Then:
1. A menu-bar icon (`eye.circle`) appears; click it.
2. If prompted, grant Accessibility permission for the running binary; the status flips to "Monitoring" without restarting.
3. Press **⌘⇧4** — an entry appears (`⇧⌘4 · Physical keyboard · <time>`) and a popup shows. Then press **Escape** to dismiss the screenshot crosshair.
4. Type normally and press plain Shift+letters — confirm **nothing** is logged.
Expected: only real modifier combos are logged; screenshot combo appears as "Physical keyboard".

- [ ] **Step 5: Verify synthetic-source detection (the core feature)**

In a second terminal, with the app running, post a synthetic ⌘⇧4:
```bash
osascript -e 'tell application "System Events" to key code 21 using {command down, shift down}'
```
Expected: a new log entry whose source is **Synthetic — <process>** (shown in red), demonstrating culprit identification. Press Escape to dismiss the screenshot crosshair.

- [ ] **Step 6: Commit**

```bash
git add Sources/HotkeySpy/HotkeySpyApp.swift Sources/HotkeySpy/MenuContentView.swift
git commit -m "feat: MenuBarExtra UI and app wiring"
```

---

### Task 12: `.app` bundle build script

**Files:**
- Create: `scripts/make-app.sh`
- Create: `Resources/Info.plist`

**Interfaces:**
- Produces: `build/HotkeySpy.app` — a runnable, unsigned bundle with a proper bundle id (so Accessibility shows "HotkeySpy" and notifications can work).

- [ ] **Step 1: Create the Info.plist template**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>HotkeySpy</string>
    <key>CFBundleDisplayName</key>     <string>HotkeySpy</string>
    <key>CFBundleIdentifier</key>      <string>com.joemo.hotkeyspy</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>HotkeySpy</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
```

- [ ] **Step 2: Create the build script**

`scripts/make-app.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

APP="build/HotkeySpy.app"
BIN_NAME="HotkeySpy"

echo "Building release binary…"
swift build -c release --product "$BIN_NAME"

BIN_PATH="$(swift build -c release --product "$BIN_NAME" --show-bin-path)/$BIN_NAME"

echo "Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
chmod +x "$APP/Contents/MacOS/$BIN_NAME"

# Ad-hoc signature so Accessibility/TCC keeps a stable identity across launches.
codesign --force --deep --sign - "$APP" || echo "codesign (ad-hoc) skipped/failed — app still runs"

echo "Done: $APP"
```

- [ ] **Step 3: Make it executable and run it**

Run:
```bash
chmod +x scripts/make-app.sh
./scripts/make-app.sh
open build/HotkeySpy.app
```
Expected: `build/HotkeySpy.app` is created; opening it shows the menu-bar icon. Grant Accessibility to **HotkeySpy** (now shown by name), then verify ⌘⇧4 is logged as in Task 11.

- [ ] **Step 4: Ignore build output and commit the script**

```bash
printf '%s\n' 'build/' '.build/' >> .gitignore
git add scripts/make-app.sh Resources/Info.plist .gitignore
git commit -m "build: script to assemble unsigned HotkeySpy.app bundle"
```

---

### Task 13: README, license, and first GitHub Release

**Files:**
- Create: `README.md`
- Create: `LICENSE` (MIT)

**Interfaces:**
- Produces: public documentation and a downloadable `.app` on the Releases page.

- [ ] **Step 1: Write `LICENSE`**

Create an MIT `LICENSE` with copyright `2026 Joe Morganelli`.

- [ ] **Step 2: Write `README.md`**

`README.md` must include:
```markdown
# HotkeySpy

A tiny macOS menu-bar app that detects **modifier-combo key presses** (⌘/⌃/⌥ combos)
and tells you whether each came from your **physical keyboard** or was **posted by
software** — so you can catch "ghost" hotkeys (e.g. a screenshot box that appears
on its own).

## Why it needs Accessibility permission
HotkeySpy uses a **listen-only** system event tap to observe key-down events. It
**never** blocks, alters, or records normal typing — only combos that include
Command, Control, or Option (Shift alone is ignored). Nothing is sent anywhere and
nothing is written to disk; the log lives in memory and clears on quit.

## Install (prebuilt, unsigned)
1. Download `HotkeySpy.app.zip` from the latest [Release](../../releases) and unzip.
2. Because it's unsigned: **right-click → Open**, then confirm. (Gatekeeper blocks
   a normal double-click the first time.)
3. Click the menu-bar eye icon → **Grant Accessibility…** and enable HotkeySpy in
   System Settings → Privacy & Security → Accessibility.

## Build from source
Requires macOS 13+ and Xcode command-line tools.
```bash
git clone https://github.com/JoeMo-GenX/hotkey_spy.git
cd hotkey_spy
swift run HotkeySpy          # run directly, or:
./scripts/make-app.sh        # produces build/HotkeySpy.app
```
Or open `Package.swift` in Xcode and press Run.

## What each log entry means
- `Physical keyboard` — a real key press (or a low-level remapper / stuck key).
- `Synthetic — <App>` (red) — another process posted this keystroke in software.
  **This is your ghost-press culprit.**
```

- [ ] **Step 3: Commit and push docs**

```bash
git add README.md LICENSE
git commit -m "docs: README and MIT license"
git push origin main
```

- [ ] **Step 4: Build the release artifact and publish**

Run:
```bash
./scripts/make-app.sh
cd build && zip -r HotkeySpy.app.zip HotkeySpy.app && cd ..
gh release create v1.0 build/HotkeySpy.app.zip \
  --title "HotkeySpy v1.0" \
  --notes "First release. Unsigned .app — right-click → Open on first launch. Requires Accessibility permission."
```
Expected: a `v1.0` Release exists at the repo with `HotkeySpy.app.zip` attached.

- [ ] **Step 5: Final full-suite check**

Run: `swift build && swift test`
Expected: build succeeds; all `HotkeySpyCore` tests PASS.

---

## Self-Review Notes

- **Spec coverage:** capture rule (Tasks 2, 5, 10) · notification popup (Tasks 7, 8) · menu-bar running log (Tasks 6, 11) · source PID identification incl. hardware/synthetic/unknown (Tasks 4, 5, 10) · tap re-enable reliability (Task 10) · listen-only (Task 10) · Accessibility permission + prompt/poll (Tasks 9, 11) · MenuBarExtra/`LSUIElement` tray app (Tasks 11, 12) · unsigned `.app` + GitHub Release (Tasks 12, 13) · toast fallback for unsigned notifications (Tasks 7, 8) · unit + integration verification (Core tasks + Task 11 steps 4–5).
- **Type consistency:** `EventNotifier.notify(_:)`, `EventLog.add/clear`, `EventBuilder.make(...)`, `Modifiers`, `EventSource.label/isSuspicious`, `summaryLine(for:)` used consistently across producing and consuming tasks.
- **Out of scope (unchanged):** file logging, code signing/notarization, configurable watch lists, pre-Ventura support, event blocking.
