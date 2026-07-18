public struct Modifiers: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let control = Modifiers(rawValue: 1 << 1)
    public static let option  = Modifiers(rawValue: 1 << 2)
    public static let shift   = Modifiers(rawValue: 1 << 3)
}
