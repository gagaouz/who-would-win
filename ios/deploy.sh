#!/usr/bin/env bash
# deploy.sh — bump build, archive, upload to TestFlight
# Usage:  cd /Users/home/WWW/who-would-win/ios && ./deploy.sh
#
# Auth: uses App Store Connect API key 2QMMTNH623 (stored at
# ~/.appstoreconnect/private_keys/AuthKey_2QMMTNH623.p8). No Xcode sign-in needed.

set -eo pipefail

SCHEME="WhoWouldWin"
ARCHIVE="build/WhoWouldWin.xcarchive"
EXPORT_PLIST="ExportOptions.plist"
ASC_KEY_ID="HD4UHKTPQJ"
ASC_ISSUER_ID="69a6de78-3cc8-47e3-e053-5b8c7c11a4d1"
ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"

cd "$(dirname "$0")"

if [ ! -f "$ASC_KEY_PATH" ]; then
  echo "❌ App Store Connect API key not found at $ASC_KEY_PATH" >&2
  exit 1
fi

# ── Bump build number ──────────────────────────────────────────────────────────
CURRENT=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" WhoWouldWin/Info.plist)
NEXT=$((CURRENT + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT" WhoWouldWin/Info.plist
echo "▶ Build number: $CURRENT → $NEXT"

# ── Archive ───────────────────────────────────────────────────────────────────
echo "▶ Archiving (this takes a minute)..."
xcodebuild -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  archive 2>&1 | grep -E "^.*(error:|ARCHIVE SUCCEEDED|ARCHIVE FAILED)" || {
    echo "❌ Archive failed" >&2; exit 1; }

# ── Export + Upload ───────────────────────────────────────────────────────────
echo "▶ Uploading to TestFlight..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "build/export_b${NEXT}" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  -authenticationKeyPath "$ASC_KEY_PATH" 2>&1 | tee /tmp/deploy_export.log | grep -E "error:|Uploaded|EXPORT SUCCEEDED|EXPORT FAILED" || true

if grep -q "EXPORT SUCCEEDED" /tmp/deploy_export.log; then
  echo ""
  echo "✅  Build $NEXT uploaded to TestFlight."
  # Persist the bumped build number into project.yml so the next xcodegen
  # generate doesn't reset it back to an already-used value.
  if [ -f project.yml ]; then
    /usr/bin/sed -i '' -E "s/^([[:space:]]+CFBundleVersion: ).*/\1\"${NEXT}\"/" project.yml
    echo "    project.yml CFBundleVersion synced to ${NEXT}."
  fi
else
  echo ""
  echo "❌ Upload failed. See /tmp/deploy_export.log for details." >&2
  exit 1
fi
