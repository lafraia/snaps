#!/usr/bin/env bash
# Builds a Developer ID–signed, notarized release of Snaps.
#   ./Scripts/release.sh            archive, notarize and package into build/release
#   ./Scripts/release.sh publish    ...then tag v<version> and publish a GitHub release
#
# Signing and notarization go through the Apple account you're signed into in Xcode
# (Xcode → Settings → Accounts). Bump CFBundleShortVersionString and CFBundleVersion
# in Resources/Info.plist before each release.
set -euo pipefail

cd "$(dirname "$0")/.."
ACTION="${1:-build}"
TEAM_ID="${TEAM_ID:-4F2YLTHL8T}"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
TAG="v$VERSION"
ARCHIVE="build/Snaps.xcarchive"
NOTARIZED="build/notarized"
OUT="build/release"

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen"; exit 1; }

if [[ "$ACTION" == "publish" ]] && git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists. Bump the version in Resources/Info.plist first."
  exit 1
fi

echo "→ Generating Xcode project"
xcodegen generate --quiet

echo "→ Archiving Snaps $VERSION"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project Snaps.xcodeproj \
  -scheme Snaps \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet

echo "→ Signing with Developer ID and uploading for notarization"
mkdir -p build
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>upload</string>
</dict>
</plist>
EOF
rm -rf build/export
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates \
  -quiet

echo "→ Waiting for Apple's notary service"
for attempt in $(seq 1 80); do
  rm -rf "$NOTARIZED"
  if xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$NOTARIZED" >build/notarize.log 2>&1; then
    break
  fi
  if [[ "$attempt" == 80 ]]; then
    echo "Notarization did not finish in time; see build/notarize.log"
    exit 1
  fi
  sleep 15
done

APP="$NOTARIZED/Snaps.app"
echo "→ Verifying"
codesign --verify --deep --strict "$APP"
xcrun stapler validate "$APP" >/dev/null
spctl --assess --type exec "$APP"

echo "→ Packaging"
rm -rf "$OUT"
mkdir -p "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Snaps-$VERSION.zip"

# Styled installer DMG (background, icon layout, volume icon) via dmgbuild.
if [[ ! -x build/.venv/bin/dmgbuild ]]; then
  python3 -m venv build/.venv
  build/.venv/bin/pip install --quiet dmgbuild
fi
build/.venv/bin/dmgbuild -s Resources/dmg/settings.py -D app="$APP" \
  "Snaps $VERSION" "$OUT/Snaps-$VERSION.dmg" >/dev/null 2>&1
(cd "$OUT" && shasum -a 256 "Snaps-$VERSION.dmg" "Snaps-$VERSION.zip" > SHA256SUMS.txt)

echo "✓ Snaps $VERSION is signed, notarized and packaged in $OUT"

if [[ "$ACTION" == "publish" ]]; then
  echo "→ Publishing GitHub release $TAG"
  git tag -a "$TAG" -m "Snaps $VERSION"
  git push origin "$TAG"
  NOTES_ARGS=(--generate-notes)
  [[ -n "${RELEASE_NOTES:-}" ]] && NOTES_ARGS=(--notes-file "$RELEASE_NOTES")
  gh release create "$TAG" \
    "$OUT/Snaps-$VERSION.dmg" \
    "$OUT/Snaps-$VERSION.zip" \
    "$OUT/SHA256SUMS.txt" \
    --title "Snaps $VERSION" \
    "${NOTES_ARGS[@]}"
fi
