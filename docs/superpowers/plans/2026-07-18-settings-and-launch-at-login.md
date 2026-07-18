# HotkeySpy Settings & Launch-at-Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Settings window (opened from a "Settings…" menu button) with three preferences — launch at login, show notifications, and how many recent events to keep — to the existing HotkeySpy menu-bar app.

**Architecture:** Keep the existing split: pure/testable `HotkeySpyCore` and thin AppKit/SwiftUI glue in the `HotkeySpy` target. One small core change (`EventLog.limit` becomes settable). New app-target pieces: `LaunchAtLogin` (SMAppService wrapper), `NotificationGate` (notifier wrapper honoring the notifications pref), `SettingsStore` (UserDefaults-backed prefs applied to the live log), `SettingsView` (the form), plus a `Window` scene and a menu button.

**Tech Stack:** Swift 5.9, SwiftUI (`Window`, `openWindow`, `@AppStorage`/UserDefaults), ServiceManagement (`SMAppService`, macOS 13+), AppKit.

## Global Constraints

- **Platform floor:** macOS 13. Use macOS-13-compatible APIs only: single-parameter `.onChange(of:perform:)`, `Window` scene, `@Environment(\.openWindow)`, `SMAppService.mainApp`. Do NOT use the two-parameter `onChange` or `SettingsLink` (macOS 14+).
- **Preference keys & defaults (exact):** `notificationsEnabled` — Bool, default `true`. `maxLogEntries` — Int, default `100`, clamped to `25...500`.
- **Launch-at-login source of truth** is `SMAppService.mainApp.status`, not a stored bool. Toggling calls `register()`/`unregister()` and re-reads status; failures are caught (logged) and the toggle reflects the real resulting status.
- **No new third-party dependencies** (ServiceManagement + SwiftUI are system frameworks).
- **The notifications pref only gates popups** — the in-menu `EventLog` records every event regardless.
- **Commits:** local git identity is already `JoeMo <129565515+JoeMo-GenX@users.noreply.github.com>` — commit normally, and add **NO `Co-Authored-By:` trailer** to any commit.
- **Builds/tests:** this repo is in a Dropbox-synced folder; always pass `--scratch-path /private/tmp/claude-501/-Users-joe-Library-CloudStorage-Dropbox-codebase-shortcut-use/0088d5c7-75cf-4740-afed-bd7f00e191cf/scratchpad/hotkeyspy-build` to every `swift build`/`swift test`.

---

### Task 1: Make `EventLog.limit` settable (live re-trim)

**Files:**
- Modify: `Sources/HotkeySpyCore/EventLog.swift`
- Test: `Tests/HotkeySpyCoreTests/EventLogTests.swift`

**Interfaces:**
- Consumes: `KeyEvent`.
- Produces: `EventLog.limit` becomes `public var limit: Int { didSet { … re-trim } }`; `init(limit:)` unchanged; `add`/`clear` unchanged in behavior.

- [ ] **Step 1: Write the failing tests**

Add to `Tests/HotkeySpyCoreTests/EventLogTests.swift` (keep the existing tests; reuse the existing `event(_:)` helper):
```swift
    func testLoweringLimitTrimsToNewest() {
        let log = EventLog(limit: 5)
        ["A", "B", "C", "D", "E"].forEach { log.add(event($0)) } // newest-first: E D C B A
        log.limit = 2
        XCTAssertEqual(log.events.map(\.combo), ["E", "D"])
    }

    func testRaisingLimitKeepsExisting() {
        let log = EventLog(limit: 3)
        ["A", "B", "C"].forEach { log.add(event($0)) }
        log.limit = 10
        XCTAssertEqual(log.events.map(\.combo), ["C", "B", "A"])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --scratch-path <BP> --filter EventLogTests`
Expected: the two new tests FAIL to compile — `limit` is not settable (`cannot assign to property: 'limit' is a 'let' constant`).

- [ ] **Step 3: Make `limit` settable with a shared trim**

Replace the body of `EventLog` so `limit` is a `var` with a `didSet` that re-trims, and `add` reuses the same trim:
```swift
import Foundation
import Combine

public final class EventLog: ObservableObject {
    @Published public private(set) var events: [KeyEvent] = []
    public var limit: Int {
        didSet { trim() }
    }

    public init(limit: Int = 100) { self.limit = limit }

    public func add(_ event: KeyEvent) {
        events.insert(event, at: 0)          // newest first
        trim()
    }

    public func clear() { events.removeAll() }

    private func trim() {
        if events.count > limit {
            events.removeLast(events.count - limit)
        }
    }
}
```

- [ ] **Step 4: Run the full core suite**

Run: `swift test --scratch-path <BP>`
Expected: all `EventLogTests` (including the 3 pre-existing + 2 new) pass; the rest of the suite still passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/HotkeySpyCore/EventLog.swift Tests/HotkeySpyCoreTests/EventLogTests.swift
git commit -m "feat: make EventLog.limit settable with live re-trim"
```

---

### Task 2: `LaunchAtLogin` (SMAppService wrapper)

**Files:**
- Create: `Sources/HotkeySpy/LaunchAtLogin.swift`

**Interfaces:**
- Produces:
```swift
enum LaunchAtLogin {
    static var isEnabled: Bool                       // SMAppService.mainApp.status == .enabled
    @discardableResult static func setEnabled(_ enabled: Bool) -> Bool  // returns resulting isEnabled
}
```
- No unit tests (system framework). Gate: clean, warning-free compile; behavior verified when the app runs in Task 5.

- [ ] **Step 1: Implement `LaunchAtLogin`**

`Sources/HotkeySpy/LaunchAtLogin.swift`:
```swift
import ServiceManagement
import Foundation

/// Thin wrapper over SMAppService for registering the app as a login item.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers/unregisters the main app as a login item, then returns the
    /// resulting state re-read from the system — so callers reflect reality
    /// even if the change was rejected. Errors are logged, not thrown.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("LaunchAtLogin: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build --scratch-path <BP>`
Expected: "Build complete!" with no warnings.

- [ ] **Step 3: Commit**

```bash
git add Sources/HotkeySpy/LaunchAtLogin.swift
git commit -m "feat: LaunchAtLogin wrapper over SMAppService"
```

---

### Task 3: `PreferenceKey`, `SettingsStore`, and `NotificationGate`

**Files:**
- Create: `Sources/HotkeySpy/SettingsStore.swift` (holds `PreferenceKey` + `SettingsStore`)
- Create: `Sources/HotkeySpy/NotificationGate.swift`

**Interfaces:**
- Produces:
  - `enum PreferenceKey { static let notificationsEnabled = "notificationsEnabled"; static let maxLogEntries = "maxLogEntries" }`
  - `final class SettingsStore: ObservableObject` with `@Published var notificationsEnabled: Bool` and `@Published var maxLogEntries: Int` (both persisted to UserDefaults on change; `maxLogEntries` clamped to 25...500 and applied to the injected `EventLog`), `init(defaults:log:)`, and `static func storedMaxLogEntries(_ defaults:) -> Int` for startup.
  - `final class NotificationGate: EventNotifier` wrapping an `EventNotifier`, forwarding only when `notificationsEnabled` (read live from UserDefaults, default true).
- No unit tests (app target). Gate: clean, warning-free compile; behavior verified in Task 5.

- [ ] **Step 1: Implement `SettingsStore` (+ `PreferenceKey`)**

`Sources/HotkeySpy/SettingsStore.swift`:
```swift
import Foundation
import Combine
import HotkeySpyCore

enum PreferenceKey {
    static let notificationsEnabled = "notificationsEnabled"
    static let maxLogEntries = "maxLogEntries"
}

private func clampLogEntries(_ n: Int) -> Int { min(500, max(25, n)) }

/// UserDefaults-backed preferences, applied to the live EventLog.
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private weak var log: EventLog?

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: PreferenceKey.notificationsEnabled) }
    }

    @Published var maxLogEntries: Int {
        didSet {
            let clamped = clampLogEntries(maxLogEntries)
            defaults.set(clamped, forKey: PreferenceKey.maxLogEntries)
            log?.limit = clamped
        }
    }

    init(defaults: UserDefaults = .standard, log: EventLog?) {
        self.defaults = defaults
        self.log = log
        self.notificationsEnabled =
            defaults.object(forKey: PreferenceKey.notificationsEnabled) as? Bool ?? true
        self.maxLogEntries =
            clampLogEntries((defaults.object(forKey: PreferenceKey.maxLogEntries) as? Int) ?? 100)
    }

    /// The persisted (clamped) limit, for initializing EventLog at startup.
    static func storedMaxLogEntries(_ defaults: UserDefaults = .standard) -> Int {
        clampLogEntries((defaults.object(forKey: PreferenceKey.maxLogEntries) as? Int) ?? 100)
    }
}
```

- [ ] **Step 2: Implement `NotificationGate`**

`Sources/HotkeySpy/NotificationGate.swift`:
```swift
import Foundation
import HotkeySpyCore

/// Wraps a notifier, forwarding only when notifications are enabled in prefs.
final class NotificationGate: EventNotifier {
    private let wrapped: EventNotifier
    private let defaults: UserDefaults

    init(wrapping wrapped: EventNotifier, defaults: UserDefaults = .standard) {
        self.wrapped = wrapped
        self.defaults = defaults
    }

    func notify(_ event: KeyEvent) {
        let enabled = defaults.object(forKey: PreferenceKey.notificationsEnabled) as? Bool ?? true
        if enabled { wrapped.notify(event) }
    }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `swift build --scratch-path <BP>`
Expected: "Build complete!" with no warnings.

- [ ] **Step 4: Commit**

```bash
git add Sources/HotkeySpy/SettingsStore.swift Sources/HotkeySpy/NotificationGate.swift
git commit -m "feat: SettingsStore prefs and NotificationGate"
```

---

### Task 4: `SettingsView` (the form)

**Files:**
- Create: `Sources/HotkeySpy/SettingsView.swift`

**Interfaces:**
- Consumes: `SettingsStore` (as `@EnvironmentObject`), `LaunchAtLogin`.
- Produces: `struct SettingsView: View`.
- No unit tests (SwiftUI). Gate: clean, warning-free compile; behavior verified in Task 5.

- [ ] **Step 1: Implement `SettingsView`**

`Sources/HotkeySpy/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch HotkeySpy at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        launchAtLogin = LaunchAtLogin.setEnabled(newValue)
                    }
                Text("For reliable startup, move HotkeySpy to your Applications folder. "
                     + "On unsigned builds the login item may not persist until the app is signed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show a popup for each detected combo", isOn: $settings.notificationsEnabled)
            }

            Section("Log") {
                Stepper("Keep last \(settings.maxLogEntries) events",
                        value: $settings.maxLogEntries, in: 25...500, step: 25)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
        .navigationTitle("HotkeySpy Settings")
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build --scratch-path <BP>`
Expected: "Build complete!" with no warnings.

- [ ] **Step 3: Commit**

```bash
git add Sources/HotkeySpy/SettingsView.swift
git commit -m "feat: SettingsView form (launch-at-login, notifications, log size)"
```

---

### Task 5: Wire settings into the app + interactive verification

**Files:**
- Modify: `Sources/HotkeySpy/HotkeySpyApp.swift`
- Modify: `Sources/HotkeySpy/MenuContentView.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `NotificationGate`, `LaunchAtLogin` (indirectly via view), `EventLog`, `SystemNotifier`, `ToastNotifier`.
- Produces: a `Window` scene with id `"settings"`; a "Settings…" menu button; the notifier wrapped by `NotificationGate`; `EventLog` initialized from the stored limit.

- [ ] **Step 1: Wire the AppDelegate + add the Settings window scene**

In `Sources/HotkeySpy/HotkeySpyApp.swift`, (a) init `log` from the stored limit, (b) create a `settings` store, (c) wrap the notifier in `NotificationGate`, (d) add a `Window` scene, (e) pass `settings` into both scenes. Replace the file's `HotkeySpyApp` struct and `AppDelegate` with:
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

        Window("HotkeySpy Settings", id: "settings") {
            SettingsView()
                .environmentObject(appDelegate.settings)
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let log = EventLog(limit: SettingsStore.storedMaxLogEntries())
    let permissions = PermissionManager()
    lazy var settings = SettingsStore(log: log)
    private var monitor: EventMonitor!
    private var notifier: EventNotifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // tray-only, no Dock icon

        _ = settings                              // instantiate the prefs store
        notifier = NotificationGate(wrapping: SystemNotifier(fallback: ToastNotifier()))
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

- [ ] **Step 2: Add the "Settings…" button to the menu**

In `Sources/HotkeySpy/MenuContentView.swift`, add the `openWindow` environment value and a Settings button in the bottom button row. Add near the top of `MenuContentView`:
```swift
    @Environment(\.openWindow) private var openWindow
```
Then replace the bottom `HStack` (the Clear log / Quit row) with:
```swift
            HStack {
                Button("Clear log") { log.clear() }
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
```

- [ ] **Step 3: Build + full test suite**

Run: `swift build --scratch-path <BP> && swift test --scratch-path <BP>`
Expected: "Build complete!" no warnings; all core tests pass (25 tests: the prior 23 + 2 new EventLog tests).

- [ ] **Step 4: Commit**

```bash
git add Sources/HotkeySpy/HotkeySpyApp.swift Sources/HotkeySpy/MenuContentView.swift
git commit -m "feat: wire Settings window, NotificationGate, and stored log limit"
```

- [ ] **Step 5: Interactive verification (controller + user — NOT a subagent)**

Build the bundle and run it: `./scripts/make-app.sh && open build/HotkeySpy.app`. Then confirm:
1. Menu shows a **"Settings…"** button; clicking it opens the **Settings window** in front.
2. **Notifications toggle:** turn it **off**, press ⌘⇧4 — the menu log still gets a new entry but **no popup** appears. Turn it **on** — popups return.
3. **Keep last N events:** set it low (e.g. 25); confirm the log never exceeds that many rows.
4. **Launch at login:** toggle it on; check **System Settings → General → Login Items** lists HotkeySpy (best-effort on the unsigned build; note it may not persist). Toggle off; confirm it's removed.
Note any interactive-only issues; the controller resolves or re-dispatches as needed.

---

## Self-Review Notes

- **Spec coverage:** Settings window + "Settings…" button (Tasks 4, 5) · launch-at-login via SMAppService with real-status source of truth + caveat note (Tasks 2, 4) · notifications toggle gating popups only, log still records (Tasks 3, 5) · keep-last-N with live re-trim + default 100 / clamp 25–500 (Tasks 1, 3, 4) · no new deps · macOS-13 APIs.
- **Type consistency:** `PreferenceKey.notificationsEnabled` / `.maxLogEntries`, `SettingsStore(defaults:log:)` / `.storedMaxLogEntries()`, `NotificationGate(wrapping:)`, `LaunchAtLogin.isEnabled` / `.setEnabled(_:)`, `EventLog.limit` used consistently across producing/consuming tasks.
- **Out of scope (unchanged):** custom watch lists, per-app filtering, themes, file logging, About window, auto-update, code signing/notarization.
