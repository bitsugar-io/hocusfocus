#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Exercise only configuration commands. Never launch the app or touch user prefs.
cli="${1:-dist/hocusfocus}"
cli="${cli:A}"
[[ -x "$cli" ]] || { print -u2 'Build the CLI with just build first.'; exit 1; }
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hocusfocus-profiles.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

"$cli" config init --file "$fixture/standard.toml" > /dev/null
"$cli" config check --file "$fixture/standard.toml" > /dev/null
standard="$(< "$fixture/standard.toml")"
[[ "$standard" == *com.mitchellh.ghostty* && "$standard" != *com.stablyai.orca* ]]

"$cli" config init --profile agents --file "$fixture/agents.toml" > /dev/null
"$cli" config check --file "$fixture/agents.toml" > /dev/null
agents="$(< "$fixture/agents.toml")"
[[ "$agents" == *com.stablyai.orca* && "$agents" == *com.apple.Terminal* ]]
[[ "$agents" == *'orca_terminal_panes = true'* ]]
[[ "$agents" == *OpenCode* && "$agents" == *Codex* && "$agents" == *com.anthropic.claudefordesktop* ]]

if "$cli" config init --profile standard --file "$fixture/agents.toml" > /dev/null 2>&1; then
    print -u2 'Initialization overwrote existing configuration.'
    exit 1
fi
[[ "$(< "$fixture/agents.toml")" == "$agents" ]]

if "$cli" config init --profile unknown --file "$fixture/unknown.toml" > /dev/null 2>&1; then
    print -u2 'An unknown profile was accepted.'
    exit 1
fi
[[ ! -e "$fixture/unknown.toml" ]]
print '4 CLI profile tests passed (standard, agents, overwrite refusal, and unknown profile).'
