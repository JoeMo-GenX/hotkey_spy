# hotkey-spy — Design Spec

**Date:** 2026-07-18
**Status:** Approved (design), pending implementation plan
**Working name:** `hotkey-spy`

## Problem

The author experiences "ghost" hotkey presses on macOS — e.g. the screenshot
capture UI appears without them pressing the screenshot shortcut. There is no
built-in way to see *what* triggered a global hotkey. This app is a small
menu-bar diagnostic that watches for modifier-combo key events, records the
combo, the source (real hardware press vs. a synthetic event posted by some
process), and the time — so the culprit behind ghost presses can be identified.

Secondary goal: a simple, polished-enough app to publish on GitHub for anyone
to use.

## Key macOS constraint (why the design is what it is)

When a *registered* global hotkey fires, macOS dispatches it directly to the
owning app. There is **no public API** for an observer app to ask "who
registered / responded to that hotkey."

What *is* possible: a low-level `CGEventTap` (requires Accessibility permission)
sees every key event. For **synthetic** events (posted in software via
`CGEventPost` etc.), the tap can read `kCGEventSourceUnixProcessID` — the PID of
the posting process. For **hardware** events this field is `0`. Therefore:

- Software-triggered ghost presses (a process faking `⌘⇧4`) → **we can name the
  process.**
- Hardware/physical ghost presses (stuck key, flaky keyboard, low-level
  remapper like Karabiner) → source reads as hardware (PID 0); we still log the
  exact combo + timestamp + frontmost app.

## Capture rule (agreed)

Log a `.keyDown` **only if its flags contain ⌘ Command, ⌃ Control, or ⌥ Option**
(in any combination). Consequences:

- Ignored: normal typing (no modifier), capital letters (Shift+letter), shifted
  symbols (Shift+number), any single plain key.
- Captured: any combo carrying a "real" modifier. **Shift is allowed to ride
  along** (so `⌘⇧3/4/5` qualify) but is never a trigger on its own.

## On-detect behavior (agreed)

1. **Notification popup** — combo + source + time, the moment it happens.
2. **Running in-memory log** in the menu bar — newest first, ~last 100 events,
   cleared on quit. No file logging.

## Distribution (agreed)

- Public GitHub repo: Swift source + Xcode project + README.
- Release: an **unsigned `.app`** zip attached to a GitHub Release (users
  right-click → Open to clear Gatekeeper). No paid Apple Developer account, no
  notarization.

## Tech stack (agreed)

- **SwiftUI `MenuBarExtra`** (macOS 13 Ventura+), agent/tray app (`LSUIElement`,
  no Dock icon).
- Detection via **Core Graphics `CGEventTap`**.
- Notifications via **`UNUserNotificationCenter`**, behind a protocol so a
  custom on-screen "toast" window can be swapped in if the unsigned build won't
  post system notifications reliably.

## Architecture

Five small, single-purpose components:

| Component | Responsibility | Depends on |
|---|---|---|
| `HotkeySpyApp` | SwiftUI `@main`, `MenuBarExtra` scene, wiring | all below |
| `PermissionManager` | check/prompt Accessibility (`AXIsProcessTrusted`) | — (AX APIs) |
| `EventMonitor` | the `CGEventTap` engine: create/enable, filter, build events | `KeyEvent`, `EventLog` |
| `KeyEvent` + formatting | model (combo, source, frontmost, timestamp) + keycode→label map | — (pure) |
| `EventLog` | observable bounded list (≈100) of recent events | `KeyEvent` |
| `Notifier` | posts notification (protocol; system + toast fallback impls) | `KeyEvent` |
| `MenuContentView` | dropdown UI: status, event list, buttons | `EventLog`, `PermissionManager` |

**Data flow:** `EventMonitor` sees a key-down → builds `KeyEvent` → appends to
`EventLog` (drives the menu) *and* hands to `Notifier`. `MenuContentView` only
renders `EventLog`. Pure filtering/formatting logic has no dependency on the
live tap, so it is directly unit-testable.

### `EventMonitor` details

- `CGEvent.tapCreate` on `.cgSessionEventTap`, `.headInsertEventTap`,
  **`.listenOnly`** (never consumes/alters events — real shortcuts are
  unaffected), `eventsOfInterest` = `.keyDown`.
- Add run-loop source; enable tap.
- Callback:
  - On `.keyDown`: read `flags`; apply capture rule (⌘/⌃/⌥ present). If kept:
    read `.keyboardEventKeycode` and `.eventSourceUnixProcessID`; resolve
    source; capture `NSWorkspace.shared.frontmostApplication`; build `KeyEvent`.
  - On `tapDisabledByTimeout` / `tapDisabledByUserInput`: **re-enable the tap**
    via `CGEvent.tapEnable` (macOS disables stalled taps — required for
    long-running reliability).
- The tap cannot be created before Accessibility permission is granted;
  `EventMonitor.start()` is (re)invoked once `PermissionManager` reports trust.

### `KeyEvent`

Fields: `combo` (e.g. `⌘⇧4`), `source` (`.hardware` / `.synthetic(appName)` /
`.unknown`), `frontmostApp: String?`, `timestamp: Date`. Includes a
keycode→base-key map so `keycode 21 + ⌘⇧` renders `⌘⇧4`. **Formatting is pure
and unit-tested.**

### UI (`MenuContentView` inside `MenuBarExtra`)

- Menu-bar icon: SF Symbol (e.g. `eye.circle`). No Dock icon.
- Status line: "Monitoring ✓" or "⚠︎ Needs Accessibility permission" + a button
  that opens the correct System Settings pane and triggers the prompt.
- Recent-events list (newest first): `⌘⇧4 · Physical keyboard · 10:32:15`.
  **Synthetic events visually flagged** (color / ⚠️) as prime suspects.
- Buttons: **Clear log**, **Quit**.

### Permissions & lifecycle

- On launch, check `AXIsProcessTrusted()`. If not trusted: show warning + "Grant
  Accessibility…" button (opens Settings, prompts). Poll for grant and start the
  monitor without requiring an app restart.
- Headless tray app; on quit, tear down the tap cleanly.

## Testing

- **Unit:** capture-rule filtering (each modifier combination incl. Shift-only
  rejection) and combo/keycode formatting — pure, no tap.
- **Integration:** post a synthetic `⌘⇧4` from the test process via `CGEventPost`
  and assert `EventMonitor` reports the test process's PID as the source. This
  directly proves the core "identify the culprit" feature.

## Repo layout (planned)

```
hotkey-spy/
├─ README.md                (what it does, build steps, permission walkthrough + why, screenshots)
├─ HotkeySpy.xcodeproj
├─ HotkeySpy/
│  ├─ HotkeySpyApp.swift
│  ├─ PermissionManager.swift
│  ├─ EventMonitor.swift
│  ├─ KeyEvent.swift
│  ├─ EventLog.swift
│  ├─ Notifier.swift
│  ├─ MenuContentView.swift
│  └─ Info.plist            (LSUIElement, bundle id, usage strings)
└─ HotkeySpyTests/
```

## GitHub setup needed from user (at implementation time)

- A repo (create via `gh` if authenticated, or user provides an empty repo URL).
- Repo name + public visibility.
- No secrets / paid account required; unsigned `.app` built locally, uploaded to
  a Release.

## Known risks

- **Unsigned notifications:** `UNUserNotificationCenter` may not post reliably on
  an unsigned build. Mitigation: `Notifier` is a protocol; ship a custom toast
  window fallback if needed.
- **Accessibility permission** is mandatory; the app is useless without it. The
  README must explain clearly *why* it needs to read key events (trust).

## Out of scope (YAGNI)

- File/persistent logging, code signing/notarization, configurable watch lists,
  pre-Ventura support, capturing/blocking events (listen-only only).
