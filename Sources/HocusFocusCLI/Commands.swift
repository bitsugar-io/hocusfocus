import AppKit
import ApplicationServices
import ArgumentParser
import HocusFocusCore

extension Configuration.Profile: ExpressibleByArgument {}

struct HocusFocusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hocusfocus", abstract: "Focus follows your mouse. On your timing.",
        discussion: "Start the background menu bar app, tune its TOML configuration, and control focus from your terminal.",
        version: "0.1.0",
        subcommands: [Start.self, Stop.self, Status.self, Pause.self, Resume.self, Reload.self, Config.self, Permissions.self]
    )
    @OptionGroup var output: OutputOptions
    mutating func run() throws { throw CleanExit.helpRequest() }
}

struct Start: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Launch the menu bar app in the background.")
    @Option(help: "Path to HocusFocus.app.") var app: String?
    @OptionGroup var output: OutputOptions
    func run() throws {
        let client = AppClient()
        try client.launch(path: app)
        try output.renderer.status(client.send("status"), title: "HocusFocus started")
    }
}

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Read the running app's focus and permission state.")
    @OptionGroup var output: OutputOptions
    func run() throws {
        let client = AppClient()
        do {
            try output.renderer.status(client.send("status"))
        } catch ClientError.notRunning {
            try output.renderer.section("HocusFocus", rows: [("running", "no")], value: ["running": false])
        }
    }
}

protocol ControlCommand: ParsableCommand {
    var output: OutputOptions { get }
    static var verb: String { get }
}
extension ControlCommand {
    func run() throws { try output.renderer.status(AppClient().send(Self.verb), title: "HocusFocus · \(Self.verb)") }
}

struct Pause: ControlCommand {
    static let configuration = CommandConfiguration(abstract: "Pause focus switching.")
    static let verb = "pause"
    @OptionGroup var output: OutputOptions
}
struct Resume: ControlCommand {
    static let configuration = CommandConfiguration(abstract: "Resume focus switching.")
    static let verb = "resume"
    @OptionGroup var output: OutputOptions
}
struct Reload: ControlCommand {
    static let configuration = CommandConfiguration(abstract: "Reload the running app's TOML configuration.")
    static let verb = "reload"
    @OptionGroup var output: OutputOptions
}

struct Stop: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Quit the background menu bar app.")
    @OptionGroup var output: OutputOptions
    func run() throws {
        let client = AppClient()
        let app = client.runningApp
        do {
            let status = try client.send("stop")
            let deadline = Date().addingTimeInterval(3)
            func stillRunning() -> Bool {
                if let app { return !app.isTerminated }
                if let pid = status.processID { return kill(pid, 0) == 0 }
                return false
            }
            while stillRunning() && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
            guard !stillRunning() else { throw ClientError.message("The app acknowledged stop but has not quit yet.") }
        } catch ClientError.notRunning {
            // Stopping an already stopped app is successful.
        }
        try output.renderer.section("HocusFocus stopped", rows: [("running", "no")], value: ["running": false])
    }
}

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Create, inspect, or validate TOML configuration.", subcommands: [Initialize.self, Show.self, Check.self, Path.self])
    @OptionGroup var output: OutputOptions
    struct FileOptions: ParsableArguments {
        @Option(name: .long, help: "Configuration file (default: ~/.config/hocusfocus/config.toml).") var file: String?
        var url: URL { file.map { URL(fileURLWithPath: $0) } ?? ConfigLocation.url }
    }
    struct Initialize: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "init", abstract: "Write default settings; refuse to overwrite an existing file.")
        @Option(help: "Settings preset: standard (Ghostty only) or agents (Orca and terminal hosts for OpenCode, Claude Code, and Codex).")
        var profile: Configuration.Profile = .standard
        @OptionGroup var output: OutputOptions
        @OptionGroup var location: FileOptions
        func run() throws {
            let url = location.url
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let source = try profile == .standard ? Configuration.defaultTOML : Configuration.preset(profile).toml()
            try Data(source.utf8).write(to: url, options: .withoutOverwriting)
            try output.renderer.section("Configuration created", rows: [("path", url.path)], value: ["path": url.path])
        }
    }
    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print the saved TOML, or its effective settings as JSON.")
        @OptionGroup var output: OutputOptions
        @OptionGroup var location: FileOptions
        func run() throws {
            let text = try String(contentsOf: location.url, encoding: .utf8)
            let config = try Configuration.parse(text)
            if output.json {
                try output.renderer.section("Configuration", rows: [], value: ConfigSummary(config, path: location.url.path))
            } else { print(text, terminator: text.hasSuffix("\n") ? "" : "\n") }
        }
    }
    struct Check: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Validate a file without launching the app.")
        @OptionGroup var output: OutputOptions
        @OptionGroup var location: FileOptions
        func run() throws {
            let config = try Configuration.parse(String(contentsOf: location.url, encoding: .utf8))
            try output.renderer.section("Configuration valid", rows: [
                ("path", location.url.path), ("hover delay", "\(config.focus.delayMS) ms"), ("apps", config.apps.mode.rawValue),
            ], value: ConfigSummary(config, path: location.url.path))
        }
    }
    struct Path: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Print the default configuration path.")
        @OptionGroup var output: OutputOptions
        func run() throws {
            if output.json { try output.renderer.section("Configuration", rows: [], value: ["path": ConfigLocation.url.path]) }
            else { print(ConfigLocation.url.path) }
        }
    }
}

private struct ConfigSummary: Encodable {
    let path: String
    let delayMS: Int
    let raiseWindow: Bool
    let orcaTerminalPanes: Bool
    let mode: String
    let apps: [String]
    let cursorStyle: String
    let pointerPulse: Bool
    init(_ config: Configuration, path: String) {
        self.path = path
        delayMS = config.focus.delayMS
        raiseWindow = config.focus.raiseWindow
        orcaTerminalPanes = config.focus.orcaTerminalPanes
        mode = config.apps.mode.rawValue
        apps = config.apps.list
        cursorStyle = config.feedback.cursorStyle.rawValue
        pointerPulse = config.feedback.pointerPulse
    }
}

struct Permissions: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check the app's Accessibility permission, or open Settings.")
    @Flag(help: "Open Accessibility settings.") var open = false
    @OptionGroup var output: OutputOptions
    func run() throws {
        if open {
            guard NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) else {
                throw ClientError.message("Could not open Accessibility settings.")
            }
        }
        // The CLI's trust is a different identity. Ask the actual menu bar app.
        let status: RuntimeStatus
        do { status = try AppClient().send("status") }
        catch ClientError.notRunning {
            try output.renderer.section("Accessibility", rows: [("app", "stopped — start HocusFocus to check its permission")], value: ["state": "unknown", "reason": "app is not running"])
            return
        }
        try output.renderer.section("Accessibility", rows: [("granted", status.accessibility ? "yes" : "permission needed")], value: ["granted": status.accessibility])
    }
}
