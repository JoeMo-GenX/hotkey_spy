import AppKit
import HotkeySpyCore

/// A borderless, non-activating panel in the top-right corner that fades out.
final class ToastNotifier: EventNotifier {
    private var panel: NSPanel?

    func notify(_ event: KeyEvent) {
        DispatchQueue.main.async { self.show(summaryLine(for: event),
                                             suspicious: event.source.isSuspicious) }
    }

    private func show(_ text: String, suspicious: Bool) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let padding: CGFloat = 14
        let size = NSSize(width: label.frame.width + padding * 2,
                          height: label.frame.height + padding * 2)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 10
        bg.layer?.backgroundColor = (suspicious
            ? NSColor.systemRed.withAlphaComponent(0.55)
            : NSColor.black.withAlphaComponent(0.35)).cgColor
        label.frame.origin = NSPoint(x: padding, y: padding)
        bg.addSubview(label)
        panel.contentView = bg

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 20,
                                         y: visible.maxY - size.height - 20))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak panel] in
            panel?.orderOut(nil)
        }
    }
}
