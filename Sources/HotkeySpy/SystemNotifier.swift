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
