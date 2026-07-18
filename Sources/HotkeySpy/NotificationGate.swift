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
