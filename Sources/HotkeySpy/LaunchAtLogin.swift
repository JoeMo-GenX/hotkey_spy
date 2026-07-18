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
