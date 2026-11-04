import AppKit
import ApplicationServices
import Testing
@testable import HocusFocus

struct TerminalPaneTests {
    private struct Node {
        var role: String
        var label: String = ""
        var bounds = CGRect.zero
        var children: [Int] = []
        var parent: Int? = nil
        var canFocus = false
    }

    private let main = CGRect(x: -1000, y: -50, width: 1000, height: 700)
    private let floating = CGRect(x: -400, y: 50, width: 300, height: 500)

    private func nodes() -> [Int: Node] {
        [
            0: Node(role: kAXWindowRole, children: [1]),
            1: Node(role: "AXWebArea", children: [10, 20, 30], parent: 0),
            10: Node(role: kAXGroupRole, bounds: main, children: [11, 12], parent: 1),
            11: Node(role: kAXImageRole, bounds: main, parent: 10),
            12: Node(role: kAXGroupRole, bounds: CGRect(x: -990, y: 0, width: 1, height: 16), children: [13], parent: 10),
            13: Node(role: kAXTextFieldRole, label: "Terminal input", parent: 12, canFocus: true),
            20: Node(role: kAXGroupRole, bounds: floating, children: [21, 22], parent: 1),
            21: Node(role: kAXImageRole, bounds: floating, parent: 20),
            22: Node(role: kAXGroupRole, bounds: CGRect(x: -390, y: 60, width: 1, height: 16), children: [23], parent: 20),
            23: Node(role: kAXTextFieldRole, label: "Terminal input", parent: 22, canFocus: true),
            30: Node(role: kAXButtonRole, label: "Settings", bounds: main, parent: 1),
        ]
    }

    private func tree(_ nodes: [Int: Node]) -> TerminalPaneTree<Int> {
        TerminalPaneTree(role: { nodes[$0]?.role }, label: { nodes[$0]?.label },
                         bounds: { nodes[$0]?.bounds }, children: { nodes[$0]?.children ?? [] },
                         parent: { nodes[$0]?.parent }, canFocus: { nodes[$0]?.canFocus ?? false })
    }

    @Test func resolvesMainAndFloatingCanvasIndependently() {
        let resolver = tree(nodes())
        #expect(resolver.target(at: CGPoint(x: -800, y: 200), hit: 11) == TerminalPaneTarget(element: 13, bounds: main))
        #expect(resolver.target(at: CGPoint(x: -200, y: 200), hit: 21) == TerminalPaneTarget(element: 23, bounds: floating))
    }

    @Test func doesNotGuessBehindButtonsOrOutsideTheCanvas() {
        let resolver = tree(nodes())
        #expect(resolver.target(at: CGPoint(x: -800, y: 200), hit: 30) == nil)
        #expect(resolver.target(at: CGPoint(x: -800, y: 200), hit: 1) == nil)
        #expect(resolver.target(at: CGPoint(x: 200, y: 200), hit: 11) == nil)
    }

    @Test func rejectsGenericTextFieldsAndInputsThatCannotFocus() {
        var nodes = nodes()
        nodes[13]?.label = "Search"
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
        nodes[13]?.label = "Terminal input"
        nodes[13]?.canFocus = false
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
    }

    @Test func doesNotFocusBehindOverlayGroupsOrDecorativeImages() {
        var nodes = nodes()
        nodes[10]?.children.append(40)
        nodes[40] = Node(role: kAXGroupRole, bounds: main, children: [41], parent: 10)
        nodes[41] = Node(role: kAXImageRole, bounds: CGRect(x: -800, y: 200, width: 20, height: 20), parent: 40)
        #expect(tree(nodes).target(at: CGPoint(x: -790, y: 210), hit: 40) == nil)
        #expect(tree(nodes).target(at: CGPoint(x: -790, y: 210), hit: 41) == nil)
    }

    @Test func rejectsMissingOrDecorativeCanvas() {
        var nodes = nodes()
        nodes[11]?.bounds = CGRect(x: -1000, y: 0, width: 20, height: 20)
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
        nodes[10]?.children = [12]
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 10) == nil)
    }

    @Test func ambiguousCyclicAndOversizedTreesFailClosed() {
        var nodes = nodes()
        nodes[12]?.children = [13, 14]
        nodes[14] = Node(role: kAXTextFieldRole, label: "Terminal input", canFocus: true)
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
        nodes[12]?.children = [12]
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
        nodes[12]?.children = Array(100...170)
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
        nodes[10]?.children = []
        nodes[10]?.parent = 10
        #expect(tree(nodes).target(at: CGPoint(x: -800, y: 200), hit: 11) == nil)
    }

    @Test func adapterIsOrcaOnlyAndOptIn() {
        #expect(TerminalPaneAccess.supports(bundleID: "com.stablyai.orca", enabled: true))
        #expect(!TerminalPaneAccess.supports(bundleID: "com.stablyai.orca", enabled: false))
        #expect(!TerminalPaneAccess.supports(bundleID: "com.microsoft.VSCode", enabled: true))
        #expect(!TerminalPaneAccess.supports(bundleID: nil, enabled: true))
    }

    @Test func dwellRequestsOnceAndChecksFocusOnLaterTick() {
        var hover = TerminalPaneHover<Int>()
        var requests: [Int] = []
        var focused = 13
        let target = TerminalPaneTarget(element: 23, bounds: floating)
        func update(_ now: Double) -> TerminalPaneHover<Int>.State {
            hover.update(target: target, now: now, delay: 0.4, isFocused: { $0 == focused },
                         requestFocus: { requests.append($0); return true })
        }
        #expect(update(0) == .waiting)
        #expect(!hover.didConfirmFocusChange)
        #expect(update(0.3) == .waiting)
        #expect(requests.isEmpty)
        #expect(update(0.4) == .verifying)
        #expect(!hover.didConfirmFocusChange)
        #expect(update(0.45) == .verifying)
        #expect(requests == [23])
        focused = 23
        #expect(update(0.5) == .focused)
        #expect(hover.didConfirmFocusChange)
        #expect(update(0.55) == .focused)
        #expect(!hover.didConfirmFocusChange)
        #expect(requests == [23])
    }

    @Test func changingPanesAndBoundsRestartsDelay() {
        var hover = TerminalPaneHover<Int>()
        var requests: [Int] = []
        func update(_ element: Int, _ bounds: CGRect, _ now: Double) -> TerminalPaneHover<Int>.State {
            hover.update(target: TerminalPaneTarget(element: element, bounds: bounds), now: now, delay: 0.4,
                         isFocused: { _ in false }, requestFocus: { requests.append($0); return true })
        }
        #expect(update(13, main, 0) == .waiting)
        #expect(update(23, floating, 0.3) == .waiting)
        #expect(update(23, floating.offsetBy(dx: 10, dy: 0), 0.6) == .waiting)
        #expect(update(23, floating.offsetBy(dx: 10, dy: 0), 0.9) == .waiting)
        #expect(requests.isEmpty)
        #expect(update(23, floating.offsetBy(dx: 10, dy: 0), 1.1) == .verifying)
        #expect(requests == [23])
    }

    @Test func resetAndLeavingCancelPendingFocus() {
        var hover = TerminalPaneHover<Int>()
        var requests = 0
        let target = TerminalPaneTarget(element: 13, bounds: main)
        func update(_ candidate: TerminalPaneTarget<Int>?, _ now: Double) -> TerminalPaneHover<Int>.State {
            hover.update(target: candidate, now: now, delay: 0.4, isFocused: { _ in false },
                         requestFocus: { _ in requests += 1; return true })
        }
        #expect(update(target, 0) == .waiting)
        hover.reset() // Pause, drag, held modifier, permission loss, or panel open.
        #expect(update(target, 1) == .waiting)
        #expect(update(nil, 1.2) == .noTarget)
        #expect(update(target, 2) == .waiting)
        #expect(requests == 0)
    }

    @Test func failuresAndUnconfirmedRequestsDoNotLoop() {
        for accepted in [false, true] {
            var hover = TerminalPaneHover<Int>()
            var requests = 0
            let target = TerminalPaneTarget(element: 13, bounds: main)
            func update(_ now: Double) -> TerminalPaneHover<Int>.State {
                hover.update(target: target, now: now, delay: 0, isFocused: { _ in false },
                             requestFocus: { _ in requests += 1; return accepted })
            }
            #expect(update(0) == (accepted ? .verifying : .failed))
            #expect(!hover.didConfirmFocusChange)
            #expect(update(1) == (accepted ? .unconfirmed : .failed))
            #expect(!hover.didConfirmFocusChange)
            #expect(update(10) == (accepted ? .unconfirmed : .failed))
            #expect(requests == 1)
        }
    }

    @Test func feedbackRecognizesNativeFocusChangeButNotInitialHoverOrResize() {
        var hover = TerminalPaneHover<Int>()
        var requests = 0
        func update(_ input: Int, _ bounds: CGRect, _ now: Double) -> TerminalPaneHover<Int>.State {
            hover.update(target: TerminalPaneTarget(element: input, bounds: bounds), now: now, delay: 0.4,
                         isFocused: { _ in true }, requestFocus: { _ in requests += 1; return true })
        }
        #expect(update(13, main, 0) == .focused)
        #expect(!hover.didConfirmFocusChange)
        #expect(update(23, floating, 1) == .focused)
        #expect(hover.didConfirmFocusChange)
        #expect(update(23, floating, 1.05) == .focused)
        #expect(!hover.didConfirmFocusChange)
        #expect(update(23, floating.offsetBy(dx: 10, dy: 0), 2) == .focused)
        #expect(!hover.didConfirmFocusChange)
        #expect(hover.update(target: nil, now: 2.1, delay: 0.4, isFocused: { _ in false }, requestFocus: { _ in false }) == .noTarget)
        #expect(!hover.didConfirmFocusChange)
        #expect(update(13, main, 2.2) == .focused)
        #expect(hover.didConfirmFocusChange)
        #expect(requests == 0)
        hover.reset()
        #expect(!hover.didConfirmFocusChange)
        #expect(update(13, main, 3) == .focused)
        #expect(!hover.didConfirmFocusChange)
    }
}
