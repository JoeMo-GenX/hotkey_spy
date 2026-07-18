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
