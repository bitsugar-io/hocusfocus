import Foundation
import Testing
@testable import HocusFocusCore

final class ConfigurationTests {
    @Test func testDefaultsFocusGhosttyOnly() {
        let config = Configuration()
        #expect(config.apps.allows(name: "Ghostty", bundleID: "com.mitchellh.ghostty"))
        #expect(!config.apps.allows(name: "Terminal", bundleID: "com.apple.Terminal"))
        #expect(!config.apps.allows(name: "iTerm2", bundleID: "com.googlecode.iterm2"))
    }

    @Test func testDefaultFileAndEmptyConfigUseSameDefaults() throws {
        #expect(try Configuration.parse(Configuration.defaultTOML) == Configuration())
        #expect(try Configuration.parse("") == Configuration())
    }

    @Test func testParsesFoundationBackedSource() throws {
        // macOS 15 file reads can return lazily bridged strings, and TOMLDecoder traps on them.
        let units = Array("# Bridged — longer than a small string\n[apps]\nmode = \"except\"\n".utf16)
        let source = NSString(characters: units, length: units.count) as String
        #expect(source.utf8.withContiguousStorageIfAvailable { _ in true } == nil)
        #expect(try Configuration.parse(source).apps.mode == .except)
    }

    @Test func testRealTOMLFeaturesAndCaseInsensitiveMatching() throws {
        let config = try Configuration.parse("""
        [focus]
        delay_ms = 1_200 # TOML numeric separator
        raise_window = false
        [apps]
        mode = 'only'
        list = [
          "Ghostty", # display name
          'com.apple.Terminal',
        ]
        [feedback]
        show_countdown = false
        """)
        #expect(config.focus.delayMS == 1200)
        #expect(!(config.focus.raiseWindow))
        #expect(!(config.feedback.pointerPulse))
        #expect(config.apps.allows(name: "ghostty", bundleID: nil))
        #expect(config.apps.allows(name: "Terminal", bundleID: "COM.APPLE.TERMINAL"))
        #expect(!(config.apps.allows(name: "Safari", bundleID: "com.apple.Safari")))
    }

    @Test func testExceptModeAndEmptyLists() throws {
        let config = try Configuration.parse("[apps]\nmode = 'except'\nlist = ['Ghostty']")
        #expect(!(config.apps.allows(name: "Ghostty", bundleID: "com.mitchellh.ghostty")))
        #expect(config.apps.allows(name: "Safari", bundleID: nil))
        let allowNone = try Configuration.parse("[apps]\nmode = 'only'\nlist = []")
        #expect(!(allowNone.apps.allows(name: "Ghostty", bundleID: nil)))
        let allowAll = try Configuration.parse("[apps]\nmode = 'except'\nlist = []")
        #expect(allowAll.apps.allows(name: "Ghostty", bundleID: nil))
    }

    @Test func testInvalidConfigurationIsRejected() {
        for source in [
            "[focus]\ndelay_ms = -1", "[focus]\ndelay_ms = 10001",
            "[focus]\ndelay_ms = '400'", "[focus]\ndelay_ms = 1.5",
            "[apps]\nmode = 'ignore'", "[apps]\nlist = [' ']",
            "[focus]\ndleay_ms = 400", "[unknown]\nx = true",
            "[feedback]\nshow_countdown = 'yes'", "not valid toml",
            "[focus]\ndelay_ms = 100\ndelay_ms = 200",
        ] {
            #expect(throws: (any Error).self) { try Configuration.parse(source) }
        }
    }

    @Test func testDelayBoundaries() throws {
        #expect(try Configuration.parse("[focus]\ndelay_ms = 0").focus.delayMS == 0)
        #expect(try Configuration.parse("[focus]\ndelay_ms = 10000").focus.delayMS == 10000)
    }
}

struct CursorStyleConfigurationTests {
    @Test func everyStyleRoundTripsWithoutChangingFocusSettings() throws {
        for style in Configuration.Feedback.CursorStyle.allCases {
            var config = Configuration()
            config.focus.delayMS = 150
            config.focus.raiseWindow = false
            config.feedback.cursorStyle = style
            let source = try config.toml()
            #expect(source.contains("cursor_style = \"\(style.rawValue)\""))
            #expect(!source.contains("pointer_pulse"))
            #expect(try Configuration.parse(source) == config)
        }
    }

    @Test func legacyBooleansPreservePreference() throws {
        for key in ["pointer_pulse", "show_countdown"] {
            #expect(try Configuration.parse("[feedback]\n\(key) = true").feedback.cursorStyle == .sweep)
            #expect(try Configuration.parse("[feedback]\n\(key) = false").feedback.cursorStyle == .off)
        }
        let source = "[feedback]\ncursor_style = 'spark'\npointer_pulse = false\nshow_countdown = false"
        #expect(try Configuration.parse(source).feedback.cursorStyle == .spark)
        #expect(try Configuration.parse("[feedback]\npointer_pulse = false\nshow_countdown = true").feedback.cursorStyle == .off)
    }

    @Test func rejectsUnknownAndWronglyTypedStyles() {
        for value in ["'flash'", "true", "42"] {
            #expect(throws: (any Error).self) {
                try Configuration.parse("[feedback]\ncursor_style = \(value)")
            }
        }
    }
}
