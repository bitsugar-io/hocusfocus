import Foundation
import Testing
@testable import HocusFocusCore

struct AgentProfileTests {
    @Test func standardProfilePreservesUpstreamDefaults() {
        #expect(Configuration.preset(.standard) == Configuration())
        #expect(!Configuration.preset(.standard).apps.allows(name: "Orca", bundleID: "com.stablyai.orca"))
    }

    @Test func agentsAllowHostAppsRegardlessOfAgentOrTitle() {
        let config = Configuration.preset(.agents)
        #expect(config.apps.mode == .only)
        #expect(config.apps.list.first == "com.stablyai.orca")
        for identifier in config.apps.list {
            #expect(config.apps.allows(name: identifier.uppercased(), bundleID: nil))
        }
        for bundleID in config.apps.list where bundleID.hasPrefix("com.") {
            #expect(config.apps.allows(name: "Any host name", bundleID: bundleID.uppercased()))
        }
        #expect(config.apps.allows(name: "OpenCode", bundleID: "any.opencoderelease"))
        #expect(config.apps.allows(name: "Codex", bundleID: "any.codexrelease"))
        #expect(config.apps.allows(name: "Claude", bundleID: "com.anthropic.claudefordesktop"))
        #expect(!config.apps.allows(name: "Safari", bundleID: "com.apple.Safari"))
        #expect(config.focus.delayMS == Configuration().focus.delayMS)
        #expect(config.focus.raiseWindow == Configuration().focus.raiseWindow)
        #expect(config.focus.orcaTerminalPanes)
        #expect(config.feedback == Configuration().feedback)
    }

    @Test func profilesRoundTrip() throws {
        for profile in Configuration.Profile.allCases {
            let config = Configuration.preset(profile)
            #expect(try Configuration.parse(config.toml()) == config)
        }
    }

    @Test func bundledExampleMatchesAgentPreset() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("config.agents.toml"), encoding: .utf8)
        #expect(try Configuration.parse(source) == Configuration.preset(.agents))
    }
}
