import AppKit
import Combine
import ApplicationServices

final class PermissionManager: ObservableObject {
    @Published var isTrusted: Bool = AXIsProcessTrusted()
    private var timer: Timer?

    /// Shows the system Accessibility prompt if not yet trusted.
    func promptIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(opts)
    }

    func openSettings() {
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Polls once per second until trust is granted, then calls onGranted once.
    func startPolling(onGranted: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.isTrusted { self.isTrusted = trusted }
            if trusted { onGranted(); t.invalidate() }
        }
    }
}
