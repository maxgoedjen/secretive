# Secretive CLI

A command-line interface for Secretive that provides full key management and SSH agent functionality, sharing the same keychain and socket path as the GUI application.

## Installation

The CLI is distributed as part of the Secretive installer package (`.pkg`). When you install Secretive via the pkg installer, the CLI binary is automatically installed to `/usr/local/bin/secretive`.

Download the latest release from [GitHub Releases](https://github.com/maxgoedjen/secretive/releases).

## Building (Development)

For local development, build the CLI using Swift Package Manager:

```bash
swift build -c release --product SecretiveCLI --package-path Sources/Packages
```

The binary will be located at `Sources/Packages/.build/release/SecretiveCLI`.

**Note:** Production builds and code signing are handled automatically by GitHub Actions. See `.github/workflows/release.yml` and `.github/workflows/nightly.yml` for details.

## Code Signing (Development)

For local development with keychain access, you must sign the CLI with the same bundle identifier and entitlements as the GUI app.

### Required Entitlements

The CLI uses the entitlements file at `SecretiveCLI.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.smartcard</key>
    <true/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.maxgoedjen.Secretive</string>
    </array>
</dict>
</plist>
```

### Signing Command

Sign the CLI binary with:

```bash
codesign --force \
  --sign "Developer ID Application: YOUR_TEAM_NAME" \
  --options runtime \
  --identifier com.maxgoedjen.Secretive.Host \
  --entitlements Sources/Packages/Sources/SecretiveCLI/SecretiveCLI.entitlements \
  Sources/Packages/.build/release/SecretiveCLI
```

Replace `YOUR_TEAM_NAME` with your actual Developer ID or use your team's signing identity.

**Important:** The `--identifier` must be `com.maxgoedjen.Secretive.Host` to match the GUI app's bundle identifier, ensuring the CLI can access the same keychain items.

## Usage

### Agent Management

Install and manage the SSH agent as a launchd service:

```bash
# Install the agent as a launchd service
secretive agent install

# Start the agent
secretive agent start

# Check agent status
secretive agent status

# Stop the agent
secretive agent stop

# Uninstall the agent
secretive agent uninstall

# Run agent in foreground (for testing)
secretive agent run
```

### Key Management

Manage SSH keys stored in the Secure Enclave:

```bash
# Generate a new key
secretive key generate "My Key Name"

# List all keys
secretive key list

# Show public key for a specific key
secretive key show "My Key Name"

# Delete a key
secretive key delete "My Key Name"

# Update key (note: attributes cannot be changed after creation)
secretive key update "My Key Name"
```

## Socket Path

The CLI uses the same socket path as the GUI app:
- Production: `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh`
- Debug: `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket-debug.ssh`

Set `SSH_AUTH_SOCK` to this path to use the agent:

```bash
export SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
```

## Keychain Access

The CLI shares the same keychain access group as the GUI app (`com.maxgoedjen.Secretive`), allowing it to:
- Access keys created by the GUI app
- Create keys that are accessible by the GUI app
- Use the same Secure Enclave storage

This is achieved by signing the CLI with the same bundle identifier (`com.maxgoedjen.Secretive.Host`) and keychain access group entitlements.

## Notes

- The CLI uses the same `SecretStoreList` setup as the GUI app, including Secure Enclave and Smart Card stores
- Keys created via CLI will appear in the GUI app and vice versa
- The agent can be run either via launchd (recommended) or in foreground mode for testing
- All key operations require appropriate authentication (Touch ID, Apple Watch, or password) as configured per key
