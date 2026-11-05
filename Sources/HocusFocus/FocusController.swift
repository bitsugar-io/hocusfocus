import AppKit
import ApplicationServices
import HocusFocusCore
import OSLog

final class FocusController {
    var config: Configuration
    var enabled = true { didSet { reset() } }
    var isConfigurationOpen: () -> Bool = { false }
    private(set) var diagnosticState = "Starting"
    var onPermissionChange: ((Bool) -> Void)?
    var onFocusFailure: ((String) -> Void)?
    private let feedback = PointerFeedback()
    private let logger = Logger(subsystem: AppControl.bundleID, category: "focus")
    private var hover = HoverState()
    private var pointerIntent = PointerHoverIntent()
    private var timer: Timer?
    private var cachedTarget: HoverWindow?
    private var cachedElement: AXUIElement?
    private var lastResolveAttempt: Double = -1
    private var wasTrusted = false
    private var lastPermissionCheck: Double = -1
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sessionActive = true

    init(config: Configuration) { self.config = config }

    func start() {
        let notifications = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(notifications.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Spotlight and Command-Tab must keep their selected app active
            // until the user moves the pointer, even if a dwell was pending.
            self?.waitForPointerMovement(at: CGEvent(source: nil)?.location)
        })
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.willSleepNotification] {
            workspaceObservers.append(notifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sessionActive = false
                self?.reset()
            })
        }
        for name in [NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(notifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sessionActive = true
                self?.reset()
            })
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.01
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func reset() {
        waitForPointerMovement(at: CGEvent(source: nil)?.location)
        cachedTarget = nil
        cachedElement = nil
        lastResolveAttempt = -1
        feedback.hide()
    }

    private func waitForPointerMovement(at point: CGPoint?) {
        hover.reset()
        pointerIntent.reset(at: point)
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPermissionCheck >= 1 {
            lastPermissionCheck = now
            let trusted = AXIsProcessTrusted()
            if trusted != wasTrusted {
                wasTrusted = trusted
                reset()
                onPermissionChange?(trusted)
            }
        }
        // Never change focus while clicking, dragging, using modifiers, or when
        // the menu or a configuration alert is open.
        if !enabled { return idle("Paused") }
        if isConfigurationOpen() { return idle("Configuration panel open") }
        if !sessionActive { return idle("Session inactive") }
        if !wasTrusted { return idle("Accessibility permission needed") }
        if NSEvent.pressedMouseButtons != 0 { return idle("Mouse button held") }
        if !NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            return idle("Modifier key held")
        }
        guard let point = CGEvent(source: nil)?.location else { return idle("Pointer unavailable") }
        guard pointerIntent.update(at: point) else {
            return idle("Waiting for pointer movement", clearTarget: false)
        }
        guard let target = WindowAccess.window(at: point, config: config) else { return idle("No allowed window under pointer") }
        if cachedTarget?.identity != target.identity || cachedTarget?.bounds != target.bounds {
            hover.reset()
            cachedElement = WindowAccess.element(for: target)
            lastResolveAttempt = now
            cachedTarget = target
        } else if cachedElement == nil && now - lastResolveAttempt >= 0.5 {
            // New windows can enter the CG list before their AX tree is ready.
            cachedElement = WindowAccess.element(for: target)
            lastResolveAttempt = now
        }
        guard let element = cachedElement else { return idle("Window not resolved through Accessibility", clearTarget: false) }
        if WindowAccess.isFocused(element, processID: target.identity.processID) {
            // Also cover keyboard switching between windows in the same app,
            // which does not produce an application-activation notification.
            waitForPointerMovement(at: point)
            return idle("Window already focused", clearTarget: false)
        }
        switch hover.update(target: target.identity, now: now, delay: Double(config.focus.delayMS) / 1000) {
        case .idle, .waiting:
            diagnosticState = "Waiting for hover delay"
            break
        case .focus:
            waitForPointerMovement(at: point)
            feedback.hide()
            // Resolve again after the delay: a window may have closed or moved.
            guard let current = WindowAccess.window(at: point, config: config),
                  current.identity == target.identity,
                  let currentElement = WindowAccess.element(for: current) else { return idle("Window changed during hover") }
            if !WindowAccess.focus(currentElement, target: current, raise: config.focus.raiseWindow) {
                diagnosticState = "Focus request failed"
                let name = current.app.localizedName ?? "Application"
                logger.error("Could not focus a window belonging to \(name, privacy: .public)")
                onFocusFailure?(config.focus.raiseWindow
                    ? "Could not focus \(name). Check Accessibility permission."
                    : "Could not focus \(name) without raising. This macOS version or app may not support it. Enable Bring window forward to use standard focus.")
            } else {
                diagnosticState = "Focus request sent"
                if config.feedback.cursorStyle != .off { feedback.showFocusAccent(style: config.feedback.cursorStyle) }
            }
        }
    }

    private func idle(_ state: String, clearTarget: Bool = true) {
        diagnosticState = state
        if clearTarget { reset() } else { hover.reset() }
    }
}
