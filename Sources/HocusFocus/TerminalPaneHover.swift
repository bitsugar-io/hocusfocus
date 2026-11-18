import Foundation

/// A focus request is not success: confirm it on a subsequent controller tick.
/// Failed/unconfirmed requests are not repeated until the hover target changes.
struct TerminalPaneHover<Element: Equatable> {
    enum State: String {
        case noTarget = "No recognized Orca terminal pane under pointer"
        case waiting = "Waiting for Orca terminal pane hover delay"
        case verifying = "Verifying Orca terminal pane focus"
        case focused = "Orca terminal pane focused"
        case failed = "Orca terminal pane focus request failed"
        case unconfirmed = "Orca terminal pane focus was not confirmed"
    }

    private var target: TerminalPaneTarget<Element>?
    private var enteredAt: Double = 0
    private var attemptedAt: Double?
    private var accepted = false
    private var lastFocusedElement: Element?
    private(set) var didConfirmFocusChange = false

    mutating func reset() { self = Self() }

    mutating func update(target candidate: TerminalPaneTarget<Element>?, now: Double, delay: Double,
                         isFocused: (Element) -> Bool, requestFocus: (Element) -> Bool) -> State {
        didConfirmFocusChange = false
        guard let candidate else {
            target = nil
            attemptedAt = nil
            accepted = false
            // Crossing a pane divider/header cancels dwell, but retain the last
            // confirmed input in this window to observe a native focus change.
            return .noTarget
        }
        if candidate != target {
            target = candidate
            enteredAt = now
            attemptedAt = nil
            accepted = false
        }
        if isFocused(candidate.element) {
            // Also recognize a change already performed by Orca's native hover
            // feature, but never pulse merely for entering an already-focused
            // pane or resizing it. An accepted request alone is not evidence.
            didConfirmFocusChange = (attemptedAt != nil && accepted)
                || (lastFocusedElement != nil && lastFocusedElement != candidate.element)
            lastFocusedElement = candidate.element
            enteredAt = now
            attemptedAt = nil
            return .focused
        }
        if let attemptedAt {
            if !accepted { return .failed }
            return now - attemptedAt < 0.5 ? .verifying : .unconfirmed
        }
        guard max(0, now - enteredAt) >= delay else { return .waiting }
        attemptedAt = now
        accepted = requestFocus(candidate.element)
        return accepted ? .verifying : .failed
    }
}
