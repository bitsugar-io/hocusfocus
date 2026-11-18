import Foundation
import CoreGraphics
import HocusFocusCore

/// Keeps slow Accessibility tree walks off the main thread. The main thread only
/// polls for the newest finished lookup and never waits for one. At most one
/// lookup and one focus request run at a time, so slow responses cannot pile up.
/// `invalidate()` makes every running job stale: its result is dropped and its
/// focus request is not sent.
final class TerminalPaneScheduler<Key: Equatable, Element: Equatable> {
    enum Poll: Equatable {
        case pending
        case ready(TerminalPaneTarget<Element>?)
    }

    private struct Lookup {
        let key: Key
        let target: TerminalPaneTarget<Element>?
        let finishedAt: Double
    }

    private let queue: DispatchQueue
    private let clock: () -> Double
    private let refreshAfter: Double
    private let lock = NSLock()
    private var generation = 0
    private var lookupRunning = false
    private var focusRunning = false
    private var lookup: Lookup?

    init(queue: DispatchQueue, refreshAfter: Double = 0.25,
         clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.queue = queue
        self.refreshAfter = refreshAfter
        self.clock = clock
    }

    func invalidate() {
        lock.withLock {
            generation += 1
            lookup = nil
        }
    }

    /// Never blocks. Returns the newest result made for `key`, or `.pending` when
    /// there is none yet. A result for another key is never returned. A result
    /// older than `refreshAfter` is still returned while a new lookup starts, so
    /// a changed pane tree is noticed. `resolve` runs on the queue.
    func poll(key: Key, resolve: @escaping () -> TerminalPaneTarget<Element>?) -> Poll {
        let (found, started): (Lookup?, Int?) = lock.withLock {
            let found = lookup.flatMap { $0.key == key ? $0 : nil }
            let outdated = found.map { clock() - $0.finishedAt >= refreshAfter } ?? true
            guard outdated, !lookupRunning else { return (found, nil) }
            lookupRunning = true
            return (found, generation)
        }
        if let started {
            queue.async { [self] in
                let target = resolve()
                lock.withLock {
                    lookupRunning = false
                    if generation == started {
                        lookup = Lookup(key: key, target: target, finishedAt: clock())
                    }
                }
            }
        }
        guard let found else { return .pending }
        return .ready(found.target)
    }

    /// Returns false when another focus request is still running. On the queue,
    /// `revalidate` must repeat every safety check and return the pane that is
    /// under the pointer right now. `perform` runs only if that pane equals `pane`
    /// and nothing invalidated the scheduler before, during or after the checks.
    @discardableResult
    func requestFocus(on pane: TerminalPaneTarget<Element>,
                      revalidate: @escaping () -> TerminalPaneTarget<Element>?,
                      perform: @escaping (Element) -> Void) -> Bool {
        let started: Int? = lock.withLock {
            guard !focusRunning else { return nil }
            focusRunning = true
            return generation
        }
        guard let started else { return false }
        queue.async { [self] in
            let isCurrent = { self.lock.withLock { self.generation == started } }
            if isCurrent(), let current = revalidate(), current == pane, isCurrent() {
                perform(current.element)
            }
            lock.withLock { focusRunning = false }
        }
        return true
    }
}

/// What a pane lookup was made for. A result is reused only for the same pointer
/// position, window and window bounds.
struct PaneLookupKey: Equatable {
    let point: CGPoint
    let window: WindowIdentity
    let bounds: CGRect
}
