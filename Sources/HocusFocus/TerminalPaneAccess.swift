import AppKit
import ApplicationServices

struct TerminalPaneTarget<Element: Equatable>: Equatable {
    let element: Element
    let bounds: CGRect
}

/// Resolves only the terminal canvas and its labelled input, not arbitrary app
/// text fields. Inject the tree so tests never access or control real windows.
struct TerminalPaneTree<Element: Equatable> {
    var role: (Element) -> String?
    var label: (Element) -> String?
    var bounds: (Element) -> CGRect?
    var children: (Element) -> [Element]
    var parent: (Element) -> Element?
    var canFocus: (Element) -> Bool

    func target(at point: CGPoint, hit: Element) -> TerminalPaneTarget<Element>? {
        let hitRole = role(hit)
        let hitIsInput = isInput(hit)
        guard hitRole == kAXImageRole || hitRole == kAXGroupRole || hitIsInput else { return nil }
        var current: Element? = hit
        var ancestors: [Element] = []
        for _ in 0..<12 {
            guard let element = current, !ancestors.contains(element) else { return nil }
            ancestors.append(element)
            if role(element) == kAXWindowRole || role(element) == "AXWebArea" { return nil }
            if role(element) == kAXGroupRole, let viewport = bounds(element),
               viewport.width >= 80, viewport.height >= 40, viewport.contains(point) {
                let nodes = children(element)
                guard nodes.count <= 64 else { return nil }
                // Orca's xterm viewport exposes a canvas-sized AXImage alongside
                // a tiny helper group containing "Terminal input". Requiring the
                // canvas bounds prevents a toolbar or settings field from being
                // mistaken for the terminal elsewhere in the same window.
                let canvas = nodes.contains { child in
                    guard role(child) == kAXImageRole, let frame = bounds(child) else { return false }
                    return (hitIsInput || element == hit || child == hit)
                        && abs(frame.minX - viewport.minX) < 2 && abs(frame.minY - viewport.minY) < 2
                        && abs(frame.width - viewport.width) < 2 && abs(frame.height - viewport.height) < 2
                }
                if canvas {
                    var budget = 64
                    var inputs: [Element] = []
                    var visited: [Element] = []
                    guard collectInputs(element, depth: 0, budget: &budget, visited: &visited, result: &inputs),
                          inputs.count == 1, canFocus(inputs[0]) else { return nil }
                    return TerminalPaneTarget(element: inputs[0], bounds: viewport)
                }
            }
            // A hit on an unrelated overlay group must not resolve to a canvas
            // behind it merely because that canvas is an ancestor's child.
            if hitRole == kAXGroupRole { return nil }
            current = parent(element)
        }
        return nil
    }

    private func isInput(_ element: Element) -> Bool {
        let value = role(element)
        return (value == kAXTextFieldRole || value == kAXTextAreaRole) && label(element) == "Terminal input"
    }

    private func collectInputs(_ element: Element, depth: Int, budget: inout Int,
                               visited: inout [Element], result: inout [Element]) -> Bool {
        guard budget > 0, depth <= 5, !visited.contains(element) else { return false }
        budget -= 1
        visited.append(element)
        if isInput(element) { result.append(element); return result.count <= 1 }
        let nodes = children(element)
        guard nodes.count <= budget else { return false }
        for child in nodes {
            guard collectInputs(child, depth: depth + 1, budget: &budget, visited: &visited, result: &result) else { return false }
        }
        return true
    }
}

struct PaneElement: Equatable {
    let raw: AXUIElement
    static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.raw, rhs.raw) }
}

enum TerminalPaneAccess {
    static func supports(bundleID: String?, enabled: Bool) -> Bool {
        enabled && bundleID == "com.stablyai.orca"
    }

    static func target(at point: CGPoint, window: AXUIElement, processID: Int32) -> TerminalPaneTarget<PaneElement>? {
        let windowChildren = WindowAccess.attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? []
        guard !windowChildren.contains(where: { WindowAccess.attribute($0, kAXRoleAttribute) as? String == kAXSheetRole }) else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        var pid: Int32 = 0
        guard AXUIElementGetPid(hit, &pid) == .success, pid == processID,
              let hitWindow = WindowAccess.attribute(hit, kAXWindowAttribute),
              CFGetTypeID(hitWindow) == AXUIElementGetTypeID(), CFEqual(hitWindow, window) else { return nil }
        return tree.target(at: point, hit: PaneElement(raw: hit))
    }

    static func isFocused(_ element: PaneElement, processID: Int32) -> Bool {
        guard let focused = WindowAccess.attribute(WindowAccess.application(processID), kAXFocusedUIElementAttribute) else { return false }
        return CFEqual(focused, element.raw)
    }

    static func requestFocus(_ element: PaneElement) -> Bool {
        AXUIElementSetAttributeValue(element.raw, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }

    private static var tree: TerminalPaneTree<PaneElement> {
        TerminalPaneTree(
            role: { WindowAccess.attribute($0.raw, kAXRoleAttribute) as? String },
            label: { WindowAccess.attribute($0.raw, kAXDescriptionAttribute) as? String },
            bounds: { WindowAccess.bounds(of: $0.raw) },
            children: { (WindowAccess.attribute($0.raw, kAXChildrenAttribute) as? [AXUIElement] ?? []).map { PaneElement(raw: $0) } },
            parent: {
                guard let value = WindowAccess.attribute($0.raw, kAXParentAttribute),
                      CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
                return PaneElement(raw: value as! AXUIElement)
            },
            canFocus: {
                var settable = DarwinBoolean(false)
                return AXUIElementIsAttributeSettable($0.raw, kAXFocusedAttribute as CFString, &settable) == .success && settable.boolValue
            }
        )
    }
}
