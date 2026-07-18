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
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let log = EventLog()
    let permissions = PermissionManager()
    private var monitor: EventMonitor!
    private var notifier: EventNotifier!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // tray-only, no Dock icon

        notifier = SystemNotifier(fallback: ToastNotifier())
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
