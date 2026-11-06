import Foundation
import TOMLDecoder

public struct Configuration: Decodable, Equatable {
    public struct Focus: Decodable, Equatable {
        public var delayMS: Int = 400
        public var raiseWindow: Bool = true
        enum CodingKeys: String, CodingKey {
            case delayMS = "delay_ms", raiseWindow = "raise_window"
        }
        public init() {}
        public init(from decoder: Decoder) throws {
            try rejectUnknownKeys(decoder, allowed: ["delay_ms", "raise_window"])
            let container = try decoder.container(keyedBy: CodingKeys.self)
            delayMS = try container.decodeIfPresent(Int.self, forKey: .delayMS) ?? 400
            raiseWindow = try container.decodeIfPresent(Bool.self, forKey: .raiseWindow) ?? true
        }
    }

    public struct Apps: Decodable, Equatable {
        public enum Mode: String, Decodable { case only, except }
        public var mode: Mode = .only
        public var list = ["com.mitchellh.ghostty"]
        enum CodingKeys: String, CodingKey { case mode, list }
        public init() {}
        public init(from decoder: Decoder) throws {
            try rejectUnknownKeys(decoder, allowed: ["mode", "list"])
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .only
            list = try container.decodeIfPresent([String].self, forKey: .list) ?? list
        }

        public func allows(name: String, bundleID: String?) -> Bool {
            let identifiers = [name, bundleID].compactMap { $0?.lowercased() }
            let matches = list.contains { identifiers.contains($0.lowercased()) }
            return mode == .only ? matches : !matches
        }
    }

    public struct Feedback: Decodable, Equatable {
        public enum CursorStyle: String, Decodable, CaseIterable, Sendable {
            case off, sweep, glow, spark
        }
        public var cursorStyle: CursorStyle = .sweep
        /// Compatibility for clients that only distinguish enabled and disabled.
        public var pointerPulse: Bool {
            get { cursorStyle != .off }
            set { cursorStyle = newValue ? (cursorStyle == .off ? .sweep : cursorStyle) : .off }
        }
        enum CodingKeys: String, CodingKey {
            case cursorStyle = "cursor_style", pointerPulse = "pointer_pulse", legacyCountdown = "show_countdown"
        }
        public init() {}
        public init(from decoder: Decoder) throws {
            try rejectUnknownKeys(decoder, allowed: ["cursor_style", "pointer_pulse", "show_countdown"])
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let pulse = try container.decodeIfPresent(Bool.self, forKey: .pointerPulse)
            let legacy = try container.decodeIfPresent(Bool.self, forKey: .legacyCountdown)
            cursorStyle = try container.decodeIfPresent(CursorStyle.self, forKey: .cursorStyle)
                ?? ((pulse ?? legacy ?? true) ? .sweep : .off)
        }
    }

    public var focus = Focus()
    public var apps = Apps()
    public var feedback = Feedback()
    enum CodingKeys: String, CodingKey { case focus, apps, feedback }
    public init() {}
    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: ["focus", "apps", "feedback"])
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focus = try container.decodeIfPresent(Focus.self, forKey: .focus) ?? Focus()
        apps = try container.decodeIfPresent(Apps.self, forKey: .apps) ?? Apps()
        feedback = try container.decodeIfPresent(Feedback.self, forKey: .feedback) ?? Feedback()
    }

    public static func parse(_ source: String) throws -> Configuration {
        // TOMLDecoder traps on bridged strings that lack contiguous UTF-8 storage.
        var source = source
        source.makeContiguousUTF8()
        let config = try TOMLDecoder().decode(Configuration.self, from: source)
        guard (0...10_000).contains(config.focus.delayMS) else {
            throw ConfigError.invalid("focus.delay_ms must be between 0 and 10000.")
        }
        guard config.apps.list.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ConfigError.invalid("apps.list cannot contain empty app names.")
        }
        return config
    }

    public static let defaultTOML = """
    # HocusFocus: edit, save, then choose Reload Configuration in the menu.
    [focus]
    delay_ms = 400
    raise_window = true

    # Use "only" for an allowlist, or "except" for an ignore list.
    # You can use app names ("Ghostty") or bundle identifiers.
    [apps]
    mode = "only"
    list = ["com.mitchellh.ghostty"]

    [feedback]
    cursor_style = "sweep"

    """

    /// JSON basic strings are TOML basic strings when slashes remain unescaped.
    /// Use an encoder so quotes, backslashes and control characters round-trip.
    public func toml() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let names = try apps.list.map { name -> String in
            String(decoding: try encoder.encode(name), as: UTF8.self)
        }.joined(separator: ", ")
        return """
        # HocusFocus — managed by the menu bar panel or edited by hand.
        [focus]
        delay_ms = \(focus.delayMS)
        raise_window = \(focus.raiseWindow)

        [apps]
        mode = "\(apps.mode.rawValue)"
        list = [\(names)]

        [feedback]
        cursor_style = "\(feedback.cursorStyle.rawValue)"

        """
    }
}

public enum ConfigError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

private struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func rejectUnknownKeys(_ decoder: Decoder, allowed: Set<String>) throws {
    let container = try decoder.container(keyedBy: AnyKey.self)
    let unknown = Set(container.allKeys.map(\.stringValue)).subtracting(allowed)
    if !unknown.isEmpty {
        let path = decoder.codingPath.map(\.stringValue).joined(separator: ".")
        throw ConfigError.invalid("Unknown configuration key in \(path.isEmpty ? "root" : path): \(unknown.sorted().joined(separator: ", ")).")
    }
}
