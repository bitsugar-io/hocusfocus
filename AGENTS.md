# AGENTS.md

Test: `just test` | Before committing: `just ready`

Read [CONTRIBUTING.md](CONTRIBUTING.md) first. It covers setup, configuration,
Accessibility and signing, project structure, code standards, testing and manual
validation, branching, commit messages, pull requests and releases, and it links
the [AI policy](AI_POLICY.md). All of it applies to agents exactly as it applies
to people. This file carries only what is specific to agents.

## Running tools

Invoke tools through `mise`, not from your path:

```bash
mise exec -- just test
```

`mise` is active in a person's shell and supplies the versions `.mise.toml`
declares. An agent's shell has no activation, so a bare `just` resolves to
whatever is installed globally, usually an older version.

The symptom is a check that fails here and passes in continuous integration, on
a file nobody edited. When that happens, establish which version ran before
treating the failure as real.

Search with `fd`, `rg` and `jaq` rather than `find`, `grep` and `jq`. `fd` and
`rg` skip the ignored `.build/` and `dist/` trees.

## The running app

The app in `dist/` is usually the one the user is running. Do not start, stop or
restart it unless the user asks, even where CONTRIBUTING.md says to run
`just stop` and `just start` after a change. A rebuilt bundle can need
Accessibility approval again, and only the user can give it.

Spawn subagents only when the user asks. Parallel SwiftPM runs contend for the
same `.build` lock.

## Reporting what you checked

Say what changed, which checks ran, and what you could not check. The manual
validation in CONTRIBUTING.md needs a person moving the pointer, so list it as
outstanding. A menu bar app that starts is not evidence that focus follows the
pointer.

## Commit trailer

When committing via Claude Code, end the message with:

```text
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```
