import Foundation
import Combine

public final class EventLog: ObservableObject {
    @Published public private(set) var events: [KeyEvent] = []
    public var limit: Int {
        didSet { trim() }
    }

    public init(limit: Int = 100) { self.limit = limit }

    public func add(_ event: KeyEvent) {
        events.insert(event, at: 0)          // newest first
        trim()
    }

    public func clear() { events.removeAll() }

    private func trim() {
        if events.count > limit {
            events.removeLast(events.count - limit)
        }
    }
}
