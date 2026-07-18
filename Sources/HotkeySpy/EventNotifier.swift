import HotkeySpyCore

protocol EventNotifier {
    func notify(_ event: KeyEvent)
}

/// Shared one-line summary used by every notifier and the menu.
func summaryLine(for event: KeyEvent) -> String {
    "\(event.combo)  ·  \(event.source.label)"
}
