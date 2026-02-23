import Foundation

/// Opaque cancellation token returned by `Scheduler.schedule`.
public protocol Cancellable {
    func cancel()
}

/// Abstraction over delayed execution so tests can control time.
public protocol Scheduler {
    @discardableResult
    func schedule(after: TimeInterval, action: @escaping () -> Void) -> Cancellable
}

// MARK: - SystemScheduler

/// Production scheduler backed by `DispatchQueue`.
public final class SystemScheduler: Scheduler {

    private let queue: DispatchQueue

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    public func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> Cancellable {
        let item = DispatchWorkItem(block: action)
        queue.asyncAfter(deadline: .now() + delay, execute: item)
        return DispatchCancellable(item: item)
    }

    private struct DispatchCancellable: Cancellable {
        let item: DispatchWorkItem
        func cancel() { item.cancel() }
    }
}

// MARK: - TestScheduler

/// Deterministic scheduler for unit tests. Actions only fire when
/// `advance(by:)` is called with enough elapsed time.
final class TestScheduler: Scheduler {

    private struct Entry {
        let deadline: TimeInterval
        let action: () -> Void
        let id: UInt64
    }

    private var entries: [UInt64: Entry] = [:]
    private var currentTime: TimeInterval = 0
    private var nextID: UInt64 = 0

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> Cancellable {
        let id = nextID
        nextID += 1
        entries[id] = Entry(deadline: currentTime + delay, action: action, id: id)
        return TestCancellable(scheduler: self, id: id)
    }

    /// Advance the virtual clock and fire any actions whose deadline has passed.
    func advance(by interval: TimeInterval) {
        currentTime += interval
        let ready = entries.values.filter { $0.deadline <= currentTime }.sorted { $0.id < $1.id }
        for entry in ready {
            entries.removeValue(forKey: entry.id)
            entry.action()
        }
    }

    var pendingCount: Int { entries.count }

    fileprivate func cancelEntry(id: UInt64) {
        entries.removeValue(forKey: id)
    }

    private struct TestCancellable: Cancellable {
        let scheduler: TestScheduler
        let id: UInt64
        func cancel() { scheduler.cancelEntry(id: id) }
    }
}
