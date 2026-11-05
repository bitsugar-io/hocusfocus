import CoreGraphics

/// A stationary pointer is not a new request to focus a window. Keep an intent
/// armed through the dwell delay, but discard it after keyboard/app activity.
public struct PointerHoverIntent {
    private var position: CGPoint?
    private var armed = false
    public init() {}

    public mutating func reset(at point: CGPoint?) {
        position = point
        armed = false
    }

    public mutating func update(at point: CGPoint) -> Bool {
        if let position, position != point { armed = true }
        position = point
        return armed
    }
}

/// Uses monotonic timestamps supplied by the caller. Window identity includes the
/// process and window ID so two windows in the same application stay distinct.
public struct WindowIdentity: Equatable {
    public let processID: Int32
    public let windowID: UInt32
    public init(processID: Int32, windowID: UInt32) {
        self.processID = processID
        self.windowID = windowID
    }
}

public struct HoverState {
    public enum Update: Equatable {
        case idle
        case waiting(progress: Double, remaining: Double)
        case focus(WindowIdentity)
    }

    private var target: WindowIdentity?
    private var enteredAt: Double = 0
    private var completed = false
    public init() {}

    public mutating func reset() {
        target = nil
        completed = false
    }

    public mutating func update(target candidate: WindowIdentity?, now: Double, delay: Double) -> Update {
        guard let candidate else {
            reset()
            return .idle
        }
        if candidate != target {
            target = candidate
            enteredAt = now
            completed = false
        }
        guard !completed else { return .idle }
        let elapsed = max(0, now - enteredAt)
        if elapsed >= delay {
            completed = true
            return .focus(candidate)
        }
        return .waiting(progress: elapsed / delay, remaining: delay - elapsed)
    }
}
