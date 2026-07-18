import Foundation

public enum EventBuilder {
    public static func make(keycode: Int, mods: Modifiers, sourcePID: Int,
                            frontmostApp: String?, timestamp: Date,
                            appName: (Int) -> String?) -> KeyEvent? {
        guard KeyFilter.shouldCapture(mods) else { return nil }

        let source: EventSource
        if sourcePID == 0 {
            source = .hardware
        } else if let name = appName(sourcePID) {
            source = .synthetic(app: name)
        } else {
            source = .unknown(pid: sourcePID)
        }

        return KeyEvent(
            combo: KeyFormatter.combo(keycode: keycode, mods: mods),
            source: source,
            frontmostApp: frontmostApp,
            timestamp: timestamp
        )
    }
}
