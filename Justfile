# Justfile — Secretive Systems Engineering Command Orchestrator
# Architecture: Native macOS Secure Enclave SSH Agent & CLI Companion

set dotenv-load := false
set export := false
set shell := ["bash", "-euo", "pipefail", "-c"]

bin := "secretive"

default: qa

# ==============================================================================
# Domain 1: Swift Development Lifecycle
# ==============================================================================

# Format code in-place according to .swiftformat (CLI focus)
fmt:
    swiftformat --config .swiftformat Sources/CLI Tests/CLITests

# Strict read-only format check for CI & Git hooks (fails on diff)
fmt-check:
    swiftformat --lint --config .swiftformat Sources/CLI Tests/CLITests

# Run complete static analysis (strict concurrency + security rules)
lint:
    swiftlint lint --strict --quiet --config .swiftlint.yml

# Run AST compiler-backed analyzer rules (unused_declaration, unused_import)
analyze:
    swift build --build-tests > .build/compiler.log 2>&1
    swiftlint analyze --strict --config .swiftlint.yml --compiler-log-path .build/compiler.log

# Fast local QA pass (format check + strict lint)
qa: fmt-check lint

# Run CLI unit and integration tests (fast, isolated, unsigned)
test *args:
    swift test --filter SecretiveCLITests --skip KeyLifecycleE2ETests --skip AgentStatusE2ETests --skip CertLifecycleE2ETests {{ args }}

# Run all swift-testing suites including snapshot regressions
test-all *args:
    swift test {{ args }}

# Run CLI snapshot regression tests
test-snapshots:
    swift test --filter SnapshotTests

# Run SSHProtocolKit parser and serializer unit tests
test-packages:
    swift test --filter SSHProtocolKitTests

# Run full package test suite via Xcode scheme
test-xcode:
    NSUnbufferedIO=YES xcrun xcodebuild -project Sources/Secretive.xcodeproj -scheme PackageTests -destination 'platform=macOS' -quiet test

# Build debug CLI executable
build:
    swift build --product {{ bin }}

# Build and sign CLI for local Secure Enclave testing
build-signed: build sign

# Sign debug CLI binary with local Apple Development certificate
sign:
    #!/usr/bin/env bash
    IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk '{print $2}')
    if [ -n "$IDENTITY" ]; then
        echo "Signing .build/debug/{{ bin }} with Apple Development identity ($IDENTITY)..."
        codesign -s "$IDENTITY" --entitlements Sources/CLI/Secretive.entitlements --force .build/debug/{{ bin }}
    else
        echo "No Apple Development identity found, falling back to ad-hoc signing..."
        codesign -s - --entitlements Sources/CLI/Secretive.entitlements --force .build/debug/{{ bin }}
    fi

# Build release CLI executable
release:
    swift build -c release --product {{ bin }}
    @ls -lh .build/release/{{ bin }}

# ==============================================================================
# Domain 2: Assets, Man Pages & Shell Completions
# ==============================================================================

# Validate manual page troff syntax using mandoc
lint-man:
    mandoc -Tlint -Werror Resources/man/secretive.1

# Validate syntax of zsh and bash completions scripts
lint-completions:
    zsh -n Resources/completions/_secretive
    bash -n Resources/completions/secretive.bash

# ==============================================================================
# Domain 3: DevSecOps, Supply Chain & Workflows
# ==============================================================================

# Scan repository history and working tree for leaked secrets
audit-secrets:
    gitleaks git --no-banner
    gitleaks dir --no-banner .

# Validate GitHub Actions workflows locally (actionlint + zizmor offline)
lint-workflows:
    actionlint -color
    zizmor --offline --min-severity high .github/workflows/

# Single-command composite gate (equivalent to local CI pass)
check-all: qa test lint-man lint-completions audit-secrets lint-workflows

# ==============================================================================
# Domain 4: Tooling & Git Hooks
# ==============================================================================

# Install repository Git hooks via Lefthook
hooks-install:
    lefthook install

# Run Lefthook pre-commit hooks manually on staged files
hooks-run:
    lefthook run pre-commit

# Clean build artifacts and temporary files
clean:
    swift package clean
    rm -rf .build .swiftpm DerivedData buildServer.json .bsp

# Generate Build Server Protocol config for SourceKit-LSP / Neovim (Xcode scheme integration)
lsp-setup scheme="SecretAgent":
    xcode-build-server config -project Sources/Secretive.xcodeproj -scheme {{ scheme }}

# Install complete developer toolchain into workstation via Homebrew
setup-tools:
    brew install swiftformat swiftlint xcode-build-server xcbeautify lefthook gitleaks actionlint zizmor mandoc
