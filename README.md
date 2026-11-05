<p align="center">
  <picture>
    <source srcset="asset/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <source srcset="asset/logo-light.svg" media="(prefers-color-scheme: light)">
    <img src="asset/logo-dark.svg" alt="HocusFocus" width="584">
  </picture>
</p>

<p align="center">Focus follows your mouse. On your timing.</p>

<p align="center">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-7542CB?style=for-the-badge"></a>
  <a href="https://www.swift.org"><img alt="Swift" src="https://img.shields.io/badge/Swift-6-B78CFF?style=for-the-badge&amp;logo=swift&amp;logoColor=white"></a>
  <img alt="macOS 13 or newer" src="https://img.shields.io/badge/macOS-13%2B-7542CB?style=for-the-badge&amp;logo=apple&amp;logoColor=white">
  <a href="https://github.com/apple/swift-argument-parser"><img alt="Swift Argument Parser" src="https://img.shields.io/badge/powered_by-Swift_Argument_Parser-B78CFF?style=for-the-badge"></a>
  <a href="https://conventionalcommits.org"><img alt="conventional commits" src="https://img.shields.io/badge/Conventional_Commits-1.0.0-7542CB?style=for-the-badge"></a>
  <a href="https://just.systems"><img alt="built with just" src="https://img.shields.io/badge/Built_with-Just-21182F?style=for-the-badge&amp;logo=just&amp;logoColor=white"></a>
  <a href="https://github.com/tekk/hovnokod-badge"><img alt="hovnokod" src="https://raw.githubusercontent.com/tekk/hovnokod-badge/main/assets/badges/hovnokod-for-the-badge.svg"></a>
</p>

I built this for myself because I wanted focus follows mouse between separate
Ghostty windows, with a hover delay I could tune from the menu bar.

<table align="center">
  <tr>
    <td align="center" width="50%"><a href="asset/configuration.png"><img src="asset/configuration.png" width="100%" alt="HocusFocus configuration with hover delay presets and app filters"></a></td>
    <td align="center" width="50%"><a href="asset/cursor-effects.gif"><img src="asset/cursor-effects.gif" width="100%" alt="Animated comparison of Off, Sweep, Glow, and Spark cursor effects"></a></td>
  </tr>
  <tr>
    <td align="center"><sub>Configuration</sub></td>
    <td align="center"><sub>Cursor effects · 3× preview</sub></td>
  </tr>
</table>

## Features

| Feature | What it does |
| --- | --- |
| Focus follows mouse | Switch between separate Ghostty windows by hovering. Ghostty is the only default app. |
| Configurable hover delay | Choose how long to hover before focus switches, using a slider, snapping presets, or an exact value. |
| Menu bar controls | Pause focus, change preferences, or quit from the focus-spark menu. |
| Cursor effects | Choose Sweep (an arc), Glow (a soft halo), Spark (four glints), or Off. Preview each effect in the menu. |
| Focus without raising | Keep another window above Ghostty while sending keyboard input to Ghostty. |
| App filters | Allow only selected apps or exclude specific apps, using friendly app names. |
| Launch at login | Start automatically when you sign in. |
| Saved preferences | Your settings are remembered between launches. |

## Quickstart

For now, run from a checkout. Requires macOS 13+, Swift 6+ from Apple's
[Command Line Tools](https://developer.apple.com/xcode/resources/), and
[just](https://just.systems).

```sh
just start
```

1. Enable **HocusFocus** in **System Settings → Privacy & Security → Accessibility**
   when prompted.
2. Click the **focus spark** in the menu bar to adjust your preferences.
3. Open two separate Ghostty windows and hover between them.

Click outside the panel or press Escape to close it.

Opening an app through Spotlight or switching with Command-Tab keeps that app
active while the pointer stays still. Move the pointer again to resume hover
focus; the configured delay still applies.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development, testing, and troubleshooting.

## License

[MIT](LICENSE).
