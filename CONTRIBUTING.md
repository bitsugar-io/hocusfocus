# Contributing

Thanks for contributing to HocusFocus.

## Before you start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md) and [AI policy](AI_POLICY.md).
- Check existing issues and pull requests before starting work.
- Keep existing TOML files compatible. Discuss breaking behavior first.
- Keep changes focused, and describe what you actually verified.

## Development setup

Start with the [quickstart](README.md#quickstart) for requirements and first run.
For optional development tools, [mise](https://mise.jdx.dev) reads the shared
[.mise.toml](.mise.toml):

```sh
mise install
```

Swift comes from the selected Apple toolchain. [Package.swift](Package.swift)
defines targets and dependencies; `Package.resolved` pins dependency versions.
Bun is used for Markdown linting.

Run `just --list` for development commands. The [justfile](justfile) defines their
behavior. After source changes, use `just stop` followed by `just start` to try
the update. Do not start or stop someone else's running app.

## Configuration

Use the panel's **TOML** button to open the active configuration file. The default
path is `~/.config/hocusfocus/config.toml`; an absolute `XDG_CONFIG_HOME` overrides
that base directory when set in the app's environment. Finder-launched apps
usually do not inherit your shell environment.

[config.example.toml](config.example.toml) documents the settings. The
[configuration parser](Sources/HocusFocusCore/Configuration.swift) defines defaults,
validation, and compatibility with older files. Use `dist/hocusfocus --help` for
the CLI command reference and a subcommand's `--help` for its options.

Panel edits save automatically and rewrite TOML comments. After an external edit,
reload before saving from the panel; it refuses to overwrite changes it has not
loaded. Failed reloads preserve working settings. An invalid file at startup
pauses focus until a successful reload.

## Accessibility and signing

Launch the packaged app through the documented workflows. Running its executable
directly can attribute Accessibility requests to the terminal. The app registers
its bundle with macOS before requesting access; the panel's permission button
retries that request and opens Settings.

Development builds are ad-hoc signed. Unchanged builds preserve the existing
signature, but code changes can require Accessibility approval again. To use an
installed signing certificate, set `HOCUSFOCUS_SIGNING_IDENTITY` before building.
Use `security find-identity -v -p codesigning` to list available identities. The
build does not create certificates or change the keychain.

If macOS retains an old permission entry, stop the app, run `just clean`, then
launch it and approve access again. Reopen System Settings if its app icon is
stale. Keep a consistent installation path when granting permission or enabling
launch at login; install in `/Applications` first for regular use.

## Project structure

```text
Package.swift                 Swift Package Manager targets and dependencies
Sources/HocusFocusCore/       TOML, hover timing, palette, and app control protocol
Sources/HocusFocusBrand/      shared native vector artwork
Sources/HocusFocus/           menu bar app, focus access, and cursor feedback
Sources/HocusFocusCLI/        Swift Argument Parser commands and styled output
Sources/BrandAssets/          generated README and app icon artwork
Tests/                        Swift Testing suites
Resources/                    app metadata and third-party notices
scripts/                      packaging, launch, stop, and workflow checks
asset/                        README artwork; local explorations are ignored
config.example.toml           example configuration
.github/                      CI, labels, and repository settings
```

## Code standards

Use Swift for app and CLI behavior. Shell scripts handle packaging and developer
workflows. Keep macOS and Accessibility calls in the app target so core behavior
can be tested without taking control of windows.

Use Swift Argument Parser's help as the command reference. Share colors and
artwork through the existing brand targets. A menu bar mark must remain legible
at small sizes. Keep exploratory designs separate from shipping assets.

Errors must describe what failed. Do not claim that a focus operation worked
because a permission check or an API request succeeded. Preserve settings after
failed validation, and never overwrite external TOML edits silently.

Keep app identity consistent with [AppControl.swift](Sources/HocusFocusCore/AppControl.swift)
across metadata, signing, CLI notifications, logs, and permission resets. Identity
changes affect macOS permissions and login items.

Focus without raising uses private macOS activation APIs adapted from yabai.
Preserve its [MIT notice](Resources/Yabai-LICENSE.txt). Future macOS versions may
require updates; failure must not fall back to raising the window.

## Testing

```sh
just test
just just-fmt-check
just md-lint
```

`just test` runs workflow tests using fake tools, the Swift Testing suites, then
configuration-profile checks using the built CLI.
Use injected services for login-item and permission tests. Tests must not
register real login items, prompt for permissions, or move focus between windows.

Use an isolated scratch directory if someone is testing the app while you work:

```sh
just test /tmp/hocusfocus-tests
```

`just build` checks packaging but does not launch the app. The packaging script
refuses to replace a changed bundle while HocusFocus is running.

### Manual validation

Automated checks do not prove that macOS delivers focus. Check interactively:

1. Grant Accessibility access and open two separate Ghostty windows. Hover
   between them and confirm keyboard input reaches the target after the delay.
2. Check quick crossings, dragging, held modifiers, and apps outside the filter.
   Opening the configuration panel should pause focus; closing it should resume.
3. Change the delay and cursor style. Check previews, Off, and Reduce Motion.
4. Disable window raising. Put Finder above part of Ghostty, hover over Ghostty's
   visible area, and confirm it receives keyboard input while Finder stays above it.
5. Show a notification. Hover Ghostty outside it and confirm focus works. Hovering
   interactive notification content should block focus behind it.
6. Check another display, full-screen windows, pause/resume, and revoked access.
7. Check launch at login and changes made through System Settings. Quit should
   exit without disabling the login item.
8. Leave the pointer over Ghostty, then open Chrome through Spotlight or switch
   with Command-Tab. Chrome must stay active until the pointer moves again.
   Repeat during a pending hover delay and when switching Ghostty windows by
   keyboard. Fresh pointer movement must start a new full hover delay.

`dist/hocusfocus status` reports the hover state for diagnosis. Report automated
and interactive verification separately.

## Before committing

Run the checks relevant to your change. Update documentation when behavior or
commands change. A successful compilation does not prove Accessibility works.
Do not reset permissions, change signing identities, or replace a live app just
to run a check.

## Branching

Create a branch before committing. Never commit directly to `main`. Agents must
not commit unless the user explicitly asks, and pushing requires separate
instruction.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org):

```text
fix(focus): ignore a passive notification host window
feat(menu): add launch at login
```

## Submitting a pull request

Describe the problem, resulting behavior, and validation. Note any manual checks
that remain. Screenshots or a short recording help reviewers assess visual
changes. Follow [AI_POLICY.md](AI_POLICY.md) for AI assistance.

## Releases

Main and pull request CI compile and test the source without producing downloads.
A `vMAJOR.MINOR.PATCH` tag triggers the [release workflow](.github/workflows/release.yml).
It tests and packages the app and CLI for the macOS runner's architecture, then
publishes a GitHub Release with the ZIP and generated notes. [cliff.toml](cliff.toml)
defines Conventional Commit groups and exclusions. Preview unreleased notes with
`just release-notes`, which uses git-cliff from `mise install`. Notes are generated from Git history;
there is no separate changelog to maintain. The archive includes license notices.
These are ad-hoc signed builds; the workflow does not notarize them or claim
Developer ID signing. A maintainer must explicitly authorize tagging or
publishing a release.
