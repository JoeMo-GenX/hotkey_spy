public enum KeyFilter {
    /// A "real" modifier is Command, Control, or Option. Shift alone does not qualify.
    public static func shouldCapture(_ mods: Modifiers) -> Bool {
        mods.contains(.command) || mods.contains(.control) || mods.contains(.option)
    }
}
