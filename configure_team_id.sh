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

if [ -z "$1" ]; then
  print_team_ids
  echo ""
  echo "> What is your Apple Developer Team ID? (looks like 1A23BDCD)"
  read TEAM_ID
else
  TEAM_ID=$1
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
echo "Successfully generated configuration at $TEAM_ID_FILE, you may now build the app using the \"Secretive\" target"
echo "You may need to close and re-open the project in Xcode if it's already open"
echo ""