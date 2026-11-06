set shell := ["zsh", "-eu", "-c"]

export CLANG_MODULE_CACHE_PATH := justfile_directory() / ".build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE := justfile_directory() / ".build/swift-module-cache"

default:
    @just --list

# Build the menu bar app and CLI into dist/.
build:
    zsh scripts/build-app.sh

# Run the configuration and hover state tests.
test:
    zsh scripts/test-workflows.sh
    zsh scripts/test-package.sh
    swift test --disable-xctest --disable-sandbox --cache-path "{{ justfile_directory() }}/.build/cache"

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
