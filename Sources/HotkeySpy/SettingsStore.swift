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
            if maxLogEntries != clamped {
                maxLogEntries = clamped   // re-clamp in memory; didSet re-fires once, then no-ops
                return
            }
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
