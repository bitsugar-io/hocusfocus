import AppKit
import ApplicationServices
import HocusFocusCore

struct HoverWindow {
    let identity: WindowIdentity
    let bounds: CGRect
    let app: NSRunningApplication
}

enum WindowAccess {
    /// Core Graphics coordinates have a top-left origin, matching Accessibility.
    static func window(at point: CGPoint, config: Configuration) -> HoverWindow? {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        for info in windows {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32,
                  pid != ProcessInfo.processInfo.processIdentifier,
                  let rawBounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: rawBounds),
                  bounds.contains(point),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let layer = info[kCGWindowLayer as String] as? Int else { continue }

            // Menus, popovers and floating panels block focus behind them.
            // Ignore system overlays above the menu/popover levels (e.g. cursor).
            if layer > Int(CGWindowLevelForKey(.popUpMenuWindow)) { continue }
            if layer != 0 {
                let owner = NSRunningApplication(processIdentifier: pid)
                if owner?.bundleIdentifier == "com.apple.notificationcenterui" {
                    let desktop = NSScreen.screens.compactMap { screen -> CGRect? in
                        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
                        return CGDisplayBounds(number.uint32Value)
                    }.reduce(CGRect.null) { $0.union($1) }
                    if WindowOcclusion.isPassThroughOverlay(
                        bundleID: owner?.bundleIdentifier, bounds: bounds, desktopBounds: desktop,
                        processID: pid, hitProcessID: hitProcessID(at: point)
                    ) { continue }
                }
                return nil
            }
            guard let id = info[kCGWindowNumber as String] as? UInt32,
                  let app = NSRunningApplication(processIdentifier: pid),
                  app.activationPolicy == .regular,
                  config.apps.allows(name: app.localizedName ?? "", bundleID: app.bundleIdentifier)
            else { return nil }
            return HoverWindow(
                identity: WindowIdentity(processID: pid, windowID: id), bounds: bounds, app: app
            )
        }
        return nil
    }

    private static func hitProcessID(at point: CGPoint) -> Int32? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &element) == .success,
              let element else { return nil }
        var pid: Int32 = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    static func element(for target: HoverWindow) -> AXUIElement? {
        let app = application(target.identity.processID)
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        // AX window titles are not unique. Match public AX bounds to the visible
        // CG window instead, including when several Ghostty windows have one title.
        let matches = windows.filter { window in
            guard let bounds = bounds(of: window) else { return false }
            return approximatelyEqual(bounds, target.bounds)
        }
        if matches.count == 1 { return matches[0] }
        // Identical bounds are ambiguous; do not guess which window to focus.
        return nil
    }

    static func isFocused(_ window: AXUIElement, processID: Int32) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID,
              let focused = attribute(application(processID), kAXFocusedWindowAttribute)
        else { return false }
        return CFEqual(window, focused)
    }

    static func focus(_ window: AXUIElement, target: HoverWindow, raise: Bool) -> Bool {
        if !raise {
            // AXMain and NSRunningApplication.activate both allow macOS to raise
            // windows. Use a separate path that preserves the window ordering.
            guard let focus = NonRaisingFocus.shared else { return false }
            let previous = target.app.isActive ? focusedWindowID(processID: target.identity.processID) : nil
            return focus.focus(processID: target.identity.processID,
                               windowID: target.identity.windowID, previousWindowID: previous)
        }
        let app = application(target.identity.processID)
        let focused = AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        let main = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raised = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        // Activating alone does not select a particular window in the same app.
        guard focused == .success || main == .success || raised == .success else { return false }
        // Activating after selecting a window also matters when another window
        // in this app already owns keyboard focus.
        return target.app.activate(options: [.activateIgnoringOtherApps])
    }

    private static func focusedWindowID(processID: Int32) -> UInt32? {
        guard let window = attribute(application(processID), kAXFocusedWindowAttribute),
              CFGetTypeID(window) == AXUIElementGetTypeID(),
              let focusedBounds = bounds(of: window as! AXUIElement),
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let matches = windows.filter { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == processID,
                  let raw = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: raw) else { return false }
            return approximatelyEqual(bounds, focusedBounds)
        }
        return matches.count == 1 ? matches[0][kCGWindowNumber as String] as? UInt32 : nil
    }

    static func application(_ pid: Int32) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        return app
    }

    static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    static func bounds(of window: AXUIElement) -> CGRect? {
        guard let position = attribute(window, kAXPositionAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(window, kAXSizeAttribute),
              CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 2 && abs(lhs.minY - rhs.minY) < 2 &&
        abs(lhs.width - rhs.width) < 2 && abs(lhs.height - rhs.height) < 2
    }
}
