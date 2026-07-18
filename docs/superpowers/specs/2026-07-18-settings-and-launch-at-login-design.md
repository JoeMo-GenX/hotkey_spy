# HotkeySpy — Settings Window & Launch-at-Login Design Spec

**Date:** 2026-07-18
**Status:** Approved (design), pending implementation plan
**Builds on:** the shipped v1.0 app (`2026-07-18-hotkey-spy-design.md`)

## Goal

Add a **Settings window** (opened from a "Settings…" menu button) exposing three
preferences, plus the ability to **launch HotkeySpy automatically at login**.

## Settings surface

- A **"Settings…"** button in the `MenuBarExtra` dropdown (grouped with Clear
  log / Quit) opens a dedicated **Settings window**.
- Implemented as a SwiftUI **`Window` scene** with a stable id, opened via
  `@Environment(\.openWindow)` → `openWindow(id:)` (robust on the macOS 13
  floor; the SwiftUI `Settings` scene's programmatic-open selector differs
  across 13/14, so a plain `Window` is used instead).
- Because the app runs as `.accessory` (LSUIElement, no Dock icon), opening the
  window also calls `NSApp.activate(ignoringOtherApps: true)` and orders the
  window front so it appears above other apps.

## Preferences

### 1. Launch at login
- Backed by **`SMAppService.mainApp`** (`ServiceManagement`, macOS 13+).
- The toggle reflects the **real OS status** (`SMAppService.mainApp.status ==
  .enabled`) — the system is the source of truth, so no stored bool that can
  drift. Toggling calls `register()` / `unregister()`.
- Error-tolerant: `register()`/`unregister()` can throw; failures are caught and
  surfaced by re-reading and showing the actual status (the toggle reverts if
  the change didn't take).
- **Known limitations (surfaced in UI note + README):**
  - Unreliable on the current **unsigned/ad-hoc** build — fully dependable only
    after code signing/notarization.
  - Login items are most reliable when the app lives in **/Applications**, not a
    build folder or Dropbox path. UI note recommends moving it there.
  - Requires the real **`.app` bundle** (does nothing under bare `swift run`).

### 2. Show notifications
- An **`@AppStorage`** bool, key `notificationsEnabled`, **default `true`**.
- Enforced by a new **`NotificationGate`** — an `EventNotifier` that wraps the
  existing notifier and forwards `notify(_:)` only when the setting is on.
  `EventMonitor`, `SystemNotifier`, and `ToastNotifier` are unchanged.
- The in-menu event log still records every event regardless of this setting;
  the toggle only affects popups.

### 3. Keep last N events
- An **`@AppStorage`** int, key `maxLogEntries`, **default `100`**, clamped to
  the range **25–500** (a `Stepper`/`Picker` in the UI).
- Requires a small **`HotkeySpyCore` change**: `EventLog.limit` becomes a
  settable `var` (currently a fixed `let`); its setter re-trims `events` when
  the limit is lowered. Covered by a unit test.
- On launch the app initializes `EventLog` with the stored value; changing the
  setting updates `log.limit` live.

## Components (new / changed)

| File | Change | Target |
|---|---|---|
| `EventLog.swift` | `limit` → settable `var` with re-trim on set; unit test | HotkeySpyCore |
| `LaunchAtLogin.swift` | new — `SMAppService.mainApp` wrapper: `isEnabled`, `setEnabled(_:)` (throwing-tolerant), `refresh()` | HotkeySpy |
| `NotificationGate.swift` | new — `EventNotifier` wrapper honoring `notificationsEnabled` | HotkeySpy |
| `SettingsStore.swift` | new — `ObservableObject` exposing `notificationsEnabled` + `maxLogEntries` (via `UserDefaults`/`@AppStorage`), applies `maxLogEntries` to the shared `EventLog` | HotkeySpy |
| `SettingsView.swift` | new — the settings form (3 controls + the launch-at-login caveat note) | HotkeySpy |
| `MenuContentView.swift` | add "Settings…" button that opens the window | HotkeySpy |
| `HotkeySpyApp.swift` | add `Window` scene for settings; wire `SettingsStore`, `NotificationGate`, stored log limit | HotkeySpy |

No new third-party dependencies — `ServiceManagement` and `SwiftUI` are system
frameworks. Architecture stays as before: pure/testable core, thin AppKit glue.

## Testing

- **Unit (core):** `EventLog.limit` setter re-trims when lowered; raising it
  keeps existing events; existing newest-first/bounded behavior still holds.
- **App target (verified by running):** launch-at-login toggle reflects/controls
  `SMAppService` status; notifications toggle silences popups while the menu log
  still updates; changing "keep last N" trims or grows the retained list.
  (`SMAppService`, `UNUserNotificationCenter`, and the window are not unit-tested
  — verified by running the `.app`.)

## Out of scope (YAGNI)

- Configurable watch list / custom hotkeys, per-app filtering, themes,
  export/file logging, an About window, sparkle-style auto-update.
- Code signing/notarization (tracked separately; it's what makes launch-at-login
  fully reliable).
