#!/bin/bash

TEAM_ID_FILE=Sources/Config/OpenSource.xcconfig

function print_team_ids() {
  echo ""
  echo "FYI, here are the team IDs found in your Xcode preferences:"
  echo ""
  
  XCODEPREFS="$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
  TEAM_KEYS=(`/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams" "$XCODEPREFS" | perl -lne 'print $1 if /^    (\S*) =/'`)
  
  for KEY in $TEAM_KEYS 
  do
      i=0
      while true ; do
          NAME=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams:$KEY:$i:teamName" "$XCODEPREFS" 2>/dev/null)
          TEAMID=$(/usr/libexec/PlistBuddy -c "Print :IDEProvisioningTeams:$KEY:$i:teamID" "$XCODEPREFS" 2>/dev/null)
          
          if [ $? -ne 0 ]; then
              break
          fi
          
          echo "$TEAMID - $NAME"
          
          i=$(($i + 1))
      done
  done
}

BUILD_CLI=false
TEAM_ID=""

for arg in "$@"; do
  case "$arg" in
    --build-cli)
      BUILD_CLI=true
      ;;
    -h|--help)
      echo "Usage: $0 [TEAM_ID] [--build-cli]"
      exit 0
      ;;
    *)
      if [ -z "$TEAM_ID" ]; then
        TEAM_ID="$arg"
      fi
      ;;
  esac
done

if [ -z "$TEAM_ID" ]; then
  print_team_ids
  echo ""
  echo "> What is your Apple Developer Team ID? (looks like 1A23BDCD)"
  read TEAM_ID
fi

if [ -z "$TEAM_ID" ]; then
  echo "You must enter a team id"
  print_team_ids
  exit 1
fi

echo "Setting team ID to $TEAM_ID"

echo "// This file was automatically generated, do not edit directly." > $TEAM_ID_FILE
echo "" >> $TEAM_ID_FILE
echo "SECRETIVE_BASE_BUNDLE_ID_OSS=${TEAM_ID}.com.example.Secretive" >> $TEAM_ID_FILE
echo "SECRETIVE_DEVELOPMENT_TEAM_OSS=${TEAM_ID}" >> $TEAM_ID_FILE

echo ""
echo "Successfully generated configuration at $TEAM_ID_FILE."
echo ""
echo "Next steps:"
echo "  1. GUI: Open Sources/Secretive.xcodeproj in Xcode and build target \"Secretive\""
echo "  2. CLI: Build and sign for local Secure Enclave access:"
echo "     just build-signed"
echo "     (or: swift build --product secretive && codesign -s \"Apple Development\" --entitlements Sources/CLI/Secretive.entitlements -f .build/debug/secretive)"
echo ""

if [ "$BUILD_CLI" = true ]; then
  echo "Building and signing CLI for local testing..."
  swift build --product secretive
  IDENTITY=$(security find-identity -p codesigning -v | grep "Apple Development" | head -n 1 | awk '{print $2}')
  if [ -n "$IDENTITY" ]; then
    echo "Signing with Apple Development identity: $IDENTITY"
    codesign -s "$IDENTITY" --entitlements Sources/CLI/Secretive.entitlements --force .build/debug/secretive
  else
    echo "No Apple Development identity found, falling back to ad-hoc signing..."
    codesign -s - --entitlements Sources/CLI/Secretive.entitlements --force .build/debug/secretive
  fi
  echo ""
  echo "CLI ready and signed at .build/debug/secretive"
fi