import Foundation

public enum EventSource: Equatable {
    case hardware
    case synthetic(app: String)
    case unknown(pid: Int)

    public var label: String {
        switch self {
        case .hardware:            return "Physical keyboard"
        case .synthetic(let app):  return "Synthetic — \(app)"
        case .unknown(let pid):    return "Synthetic — pid \(pid)"
        }
    }

    /// Anything not from the physical keyboard is a ghost-press suspect.
    public var isSuspicious: Bool {
        if case .hardware = self { return false }
        return true
    }
}

public struct KeyEvent: Identifiable, Equatable {
    public let id: UUID
    public let combo: String
    public let source: EventSource
    public let frontmostApp: String?
    public let timestamp: Date

    public init(id: UUID = UUID(), combo: String, source: EventSource,
                frontmostApp: String?, timestamp: Date) {
        self.id = id
        self.combo = combo
        self.source = source
        self.frontmostApp = frontmostApp
        self.timestamp = timestamp
    }
}
