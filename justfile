set shell := ["zsh", "-eu", "-c"]

export CLANG_MODULE_CACHE_PATH := justfile_directory() / ".build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE := justfile_directory() / ".build/swift-module-cache"

default:
    @just --list

# Build the menu bar app and CLI into dist/.
build:
    zsh scripts/build-app.sh

# Run workflow, Swift, and CLI profile tests without launching the app.
test scratch_path=(justfile_directory() / ".build"):
    zsh scripts/test-workflows.sh
    zsh scripts/test-package.sh
    swift test --disable-xctest --disable-sandbox --cache-path "{{ justfile_directory() }}/.build/cache" --scratch-path "{{ scratch_path }}"
    zsh scripts/test-cli-profiles.sh "$(swift build --show-bin-path --disable-sandbox --cache-path '{{ justfile_directory() }}/.build/cache' --scratch-path '{{ scratch_path }}')/hocusfocus"

# Launch the existing app in the background without building.
run:
    zsh scripts/run-app.sh

# Build the standalone app, then start it in the background.
start: build
    zsh scripts/run-app.sh

# Quit the running menu bar app.
stop:
    zsh scripts/stop-app.sh

# Reset only HocusFocus's Accessibility authorization; keep the build intact.
clean:
    zsh scripts/reset-accessibility.sh

# Check the bundled example without starting focus switching.
check-config:
    dist/hocusfocus config check --file config.example.toml
    dist/hocusfocus config check --file config.agents.toml

# Check configuration profiles using the built CLI without launching the app.
test-cli-profiles:
    zsh scripts/test-cli-profiles.sh

# Check Markdown using the same markdownlint-cli2 version as CI.
md-lint:
    bunx --bun markdownlint-cli2@0.24.0 '**/*.md'

# Format the justfile.
just-fmt:
    just --unstable --fmt

# Check the justfile's formatting.
just-fmt-check:
    just --unstable --fmt --check

# Preview notes for commits since the last release; writes nothing.
release-notes:
    git-cliff --config cliff.toml --unreleased --strip header

# Run the local checks without launching the app.
ready: just-fmt-check md-lint test
