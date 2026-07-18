import Foundation
import Combine

public final class EventLog: ObservableObject {
    @Published public private(set) var events: [KeyEvent] = []
    private let limit: Int

    public init(limit: Int = 100) { self.limit = limit }

    public func add(_ event: KeyEvent) {
        events.insert(event, at: 0)          // newest first
        if events.count > limit {
            events.removeLast(events.count - limit)
        }
    }

    public func clear() { events.removeAll() }
}
