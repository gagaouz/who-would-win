#!/usr/bin/env bash
# deploy.sh — bump build, drop MTU, archive+upload to TestFlight, restore MTU
# Usage:  cd /Users/home/WWW/who-would-win/ios && ./deploy.sh
#
# Requires sudo for MTU changes — you'll be prompted once at the start.

set -e

INTERFACE="en8"
SCHEME="WhoWouldWin"
ARCHIVE="build/WhoWouldWin.xcarchive"
EXPORT_PLIST="build/ExportOptions.plist"

cd "$(dirname "$0")"

# ── Pre-auth sudo so it doesn't interrupt the middle of the build ──────────────
echo "▶ Authenticating sudo (needed for MTU changes)..."
sudo -v

# ── Bump build number ──────────────────────────────────────────────────────────
CURRENT=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" WhoWouldWin/Info.plist)
NEXT=$((CURRENT + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT" WhoWouldWin/Info.plist
echo "▶ Build number: $CURRENT → $NEXT"

# ── Drop MTU ──────────────────────────────────────────────────────────────────
echo "▶ Dropping MTU to 1500 on $INTERFACE..."
sudo ifconfig "$INTERFACE" mtu 1500

# ── Archive ───────────────────────────────────────────────────────────────────
echo "▶ Archiving (this takes a minute)..."
xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  archive 2>&1 | grep -E "^.*(error:|ARCHIVE SUCCEEDED|ARCHIVE FAILED)"

# ── Export + Upload ───────────────────────────────────────────────────────────
echo "▶ Uploading to TestFlight..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "build/export_b${NEXT}" \
  -exportOptionsPlist "$EXPORT_PLIST" 2>&1 | grep -E "error:|Uploaded|EXPORT SUCCEEDED|EXPORT FAILED"

# ── Restore MTU ───────────────────────────────────────────────────────────────
echo "▶ Restoring MTU to 9000 on $INTERFACE..."
sudo ifconfig "$INTERFACE" mtu 9000

echo ""
echo "✅  Build $NEXT uploaded to TestFlight. MTU restored to 9000."
