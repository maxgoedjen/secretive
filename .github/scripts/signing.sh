#!/bin/bash
# signing.sh — Import Apple code-signing credentials into a temporary CI keychain.
# Called from release.yml, nightly.yml, and test.yml when signing is needed.
#
# Required env vars:
#   SIGNING_DATA        — base64-encoded .p12 certificate bundle
#   SIGNING_PASSWORD    — password for the .p12 bundle
#   HOST_PROFILE_DATA   — base64-encoded Secretive.app provisioning profile
#   AGENT_PROFILE_DATA  — base64-encoded SecretAgent.app provisioning profile
#   CLI_PROFILE_DATA    — base64-encoded CLI provisioning profile (optional)
#   APPLE_API_KEY_DATA  — base64-encoded App Store Connect API key (.p8)
#   APPLE_API_KEY_ID    — App Store Connect API key ID

set -euo pipefail

KEYCHAIN_NAME="ci.keychain"
KEYCHAIN_PASSWORD="ci"

# ── 1. Import certificate and private key into a fresh temporary keychain ──

echo "$SIGNING_DATA" | base64 -d -o Signing.p12

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security default-keychain -s "$KEYCHAIN_NAME"
security list-keychains -s "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

security import ./Signing.p12 \
  -k "$KEYCHAIN_NAME" \
  -P "$SIGNING_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12

# Allow codesign, apple-tool, and apple to access the key without prompting
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_NAME"

# ── 2. Install provisioning profiles ────────────────────────────────────────

PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILES_DIR"

install_profile() {
  local VAR_NAME="$1"
  local PROFILE_DATA="${!VAR_NAME:-}"

  if [ -z "$PROFILE_DATA" ]; then
    echo "⚠ $VAR_NAME not set — skipping profile installation"
    return
  fi

  local TMP
  TMP=$(mktemp)
  echo "$PROFILE_DATA" | base64 -d -o "$TMP"

  # Extract UUID from the binary plist embedded in the profile
  local UUID
  UUID=$(grep UUID -A1 -a "$TMP" | grep -io "[-A-F0-9]\{36\}" | head -1)

  if [ -z "$UUID" ]; then
    echo "⚠ Could not extract UUID from $VAR_NAME — profile may be malformed"
    rm -f "$TMP"
    return
  fi

  cp "$TMP" "$PROFILES_DIR/$UUID.provisionprofile"
  rm -f "$TMP"
  echo "✓ Installed profile $VAR_NAME → $UUID.provisionprofile"
}

install_profile HOST_PROFILE_DATA
install_profile AGENT_PROFILE_DATA
install_profile CLI_PROFILE_DATA

# ── 3. Install App Store Connect API key ─────────────────────────────────────

mkdir -p ~/.private_keys
echo -n "$APPLE_API_KEY_DATA" > ~/.private_keys/AuthKey_"$APPLE_API_KEY_ID".p8
echo "✓ Installed ASC API key AuthKey_$APPLE_API_KEY_ID.p8"
