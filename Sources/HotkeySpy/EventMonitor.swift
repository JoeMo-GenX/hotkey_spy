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

    deinit { stop() }

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
