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
