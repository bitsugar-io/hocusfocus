# Orca + OpenCode, Claude Code, and Codex

Use two complementary focus features:

| Scope | Owner | Setup |
| --- | --- | --- |
| Between separate macOS windows | HocusFocus | Initialize the `agents` profile below. |
| Between visible terminal panes inside Orca, including its floating workspace | HocusFocus's opt-in Orca adapter | Enable **Focus Orca terminal panes** or `focus.orca_terminal_panes = true` (included in the `agents` profile). |

Orca is optional. Running `opencode`, `claude`, or `codex` directly in an allowed
terminal works with the same HocusFocus configuration. Standalone OpenCode,
Claude, and Codex desktop windows are also allowed. No Orca process or CLI is
needed by HocusFocus.

Orca also has its own **Settings → Terminal → Focus Follows Mouse** toggle.
It did not resolve floating-workspace switching during testing, so the optional
adapter directly focuses Orca's recognized terminal input through Accessibility.
It never clicks, types, submits input, or patches Orca. Disable the native Orca
toggle if you want HocusFocus alone to control the delay and pause behavior.
Hidden tabs, structured chat panels, editors, and arbitrary text fields are not
pane-focus targets. The adapter depends on Orca's current Accessibility layout;
an unsupported layout is left alone rather than guessed.

## Set up window focus

Build without launching anything:

```sh
just build
just check-config
just test-cli-profiles
dist/hocusfocus config init --profile agents
dist/hocusfocus config check
```

Initialization refuses to overwrite an existing configuration. To preview the
profile separately, use:

```sh
dist/hocusfocus config init --profile agents --file "$PWD/agents.preview.toml"
dist/hocusfocus config show --file "$PWD/agents.preview.toml"
```

If the selected Command Line Tools reject the package manifest despite reporting
Swift 6+, select the installed full Xcode toolchain for the command without
changing the machine-wide developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer just build
```

For an existing setup, merge the desired host app identifiers from
[config.agents.toml](config.agents.toml) into your current `[apps].list`, preserving
your other settings. Use `dist/hocusfocus config path` to locate the active file.
If the app is running, apply external changes with `dist/hocusfocus reload`.

When ready to run it yourself:

```sh
just run
```

Approve **HocusFocus** in **System Settings → Privacy & Security → Accessibility**.
Enabling launch at login is optional; these setup commands do not enable it.

## What the profile changes

- Allows Orca, cmux, Ghostty, Apple Terminal, iTerm2, VS Code, and Cursor windows.
- Also allows standalone OpenCode and Codex apps by display name, and Claude by
  its bundle ID. This includes all windows of those apps, not only coding views.
- Keeps the 400 ms hover delay, window raising, and Sweep cursor feedback.
- Enables focus-only Orca terminal-pane targeting, including its in-app floating
  workspace. Other hosts still use window focus or their own pane-hover feature.
- Leaves unlisted applications alone. Missing host apps are harmless.
- Matches host app bundle IDs or desktop display names, not terminal titles or
  CLI process names. OpenCode, Claude Code, and Codex need no hooks or
  configuration changes.
- Allows the entire host app, including non-agent windows. This is not a filter
  that can distinguish an agent terminal from another window of the same app.

For another terminal host, add its name or bundle ID using the menu bar's app
picker or `[apps].list`. Do not add a CLI executable name as a substitute for its
terminal host. For splits inside a non-Orca terminal, use that terminal's native
pane-hover setting if available; HocusFocus itself only switches macOS windows.
Browser-based agent UIs require explicitly allowing the browser, which also
allows its unrelated windows; the profile does not enable browsers by default.

`config init` without `--profile agents` retains upstream's Ghostty-only defaults
and leaves the Orca adapter disabled. Existing configurations also leave it
disabled until you turn it on in the panel or add this to `[focus]`:

```toml
orca_terminal_panes = true
```

The adapter only acts in an allowed, already-focused Orca window. Switching in
from another app first uses the normal window delay, then the pane delay. Both
layers honor HocusFocus pause, mouse-button and modifier guards, and configuration
panel suppression. Pane targets are rechecked after the delay; requests are
verified on a later tick and are not retried repeatedly if Orca rejects them.
The selected cursor accent fires once after a pane-focus change is confirmed,
including changes observed from Orca's native hover feature. Merely hovering an
already-focused pane does not pulse. Orca's separate native setting is not paused
by HocusFocus.

## Check both layers interactively

1. Enable **Focus Orca terminal panes**, disable Orca's native toggle for an
   isolated test, and put a normal terminal and floating-workspace terminal side
   by side. Hover both directions and wait the configured delay. On an idle test
   shell, type a harmless comment without submitting it to confirm keyboard
   routing. Check ordinary split terminal panes too.
2. Open a second allowed app window. Hover between it and Orca, wait 400 ms,
   and confirm keyboard input reaches the intended window.
3. Check quick pointer crossings, dragging, held modifiers, pause/resume, settings
   fields, pane headers, and an unlisted app such as Safari. These must not
   trigger unwanted HocusFocus window or pane switching.
4. Repeat with your OpenCode, Claude Code, and Codex terminal layouts. Never use
   a live agent prompt or permission dialog as the target of an automated click
   or typing test.

Compilation and configuration tests do not prove real macOS keyboard focus.
Use `dist/hocusfocus status` for window/pane diagnostics. A pane focus request is
not reported as focused until Accessibility confirms it. That still does not
prove terminal keyboard routing; verify real input manually. HocusFocus does not
report Orca's separate native pane setting.
