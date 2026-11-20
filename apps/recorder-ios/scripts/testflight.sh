#!/usr/bin/env bash
set -euo pipefail
umask 077

for key in APPLE_TEAM_ID IOS_BUNDLE_ID APPLE_CERTIFICATE_P12_BASE64 APPLE_CERTIFICATE_PASSWORD APPLE_PROFILE_BASE64 APPSTORE_API_KEY_ID APPSTORE_API_ISSUER_ID APPSTORE_API_PRIVATE_KEY_BASE64; do
  if [ -z "$(printenv "$key")" ]; then
    echo "::error::Missing required GitHub environment secret: $key"
    exit 1
  fi
done
test "$GITHUB_REF" = "refs/heads/main" || { echo "::error::main only"; exit 1; }

WORK="$RUNNER_TEMP/signal-echoes-signing"
mkdir -p "$WORK" "$HOME/Library/MobileDevice/Provisioning Profiles" "$HOME/.appstoreconnect/private_keys"
chmod 700 "$WORK"
KEYCHAIN="$WORK/app-signing.keychain-db"
PROFILE_DEST=""
API_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_$APPSTORE_API_KEY_ID.p8"
cleanup() {
  security delete-keychain "$KEYCHAIN" 2>/dev/null || true
  rm -rf "$WORK"
  if [ -n "$PROFILE_DEST" ]; then rm -f "$PROFILE_DEST"; fi
  rm -f "$API_KEY_FILE"
}
trap cleanup EXIT

printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 -D > "$WORK/distribution.p12"
printf '%s' "$APPLE_PROFILE_BASE64" | base64 -D > "$WORK/profile.mobileprovision"
printf '%s' "$APPSTORE_API_PRIVATE_KEY_BASE64" | base64 -D > "$API_KEY_FILE"
chmod 600 "$WORK/distribution.p12" "$WORK/profile.mobileprovision" "$API_KEY_FILE"
security cms -D -i "$WORK/profile.mobileprovision" > "$WORK/profile.plist"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$WORK/profile.plist")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$WORK/profile.plist")"
PROFILE_DEST="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
cp "$WORK/profile.mobileprovision" "$PROFILE_DEST"

KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/distribution.p12" -P "$APPLE_CERTIFICATE_PASSWORD" -t cert -f pkcs12 -k "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN"
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

cd apps/recorder-ios
xcodegen generate --spec project.yml
cd ../..
xcodebuild archive \
  -project apps/recorder-ios/SignalEchoes.xcodeproj \
  -scheme SignalEchoes -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$WORK/SignalEchoes.xcarchive" \
  "DEVELOPMENT_TEAM=$APPLE_TEAM_ID" "PRODUCT_BUNDLE_IDENTIFIER=$IOS_BUNDLE_ID" \
  "CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER" "CODE_SIGN_STYLE=Manual" \
  "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_NAME" CODE_SIGNING_ALLOWED=YES -quiet

python3 - "$IOS_BUNDLE_ID" "$APPLE_TEAM_ID" "$PROFILE_NAME" "$WORK/ExportOptions.plist" <<'PY'
import plistlib,sys
bundle,team,profile,path=sys.argv[1:]
with open(path,"wb") as f:
    plistlib.dump({"method":"app-store-connect","destination":"export",
                   "signingStyle":"manual","teamID":team,
                   "provisioningProfiles":{bundle:profile}},f)
PY
codesign --verify --deep --strict --verbose=2 "$WORK/SignalEchoes.xcarchive/Products/Applications/SignalEchoes.app"
xcodebuild -exportArchive -archivePath "$WORK/SignalEchoes.xcarchive" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/Exported" -quiet
test -f "$WORK/Exported/SignalEchoes.ipa"
xcrun altool --upload-app -f "$WORK/Exported/SignalEchoes.ipa" -t ios \
  --apiKey "$APPSTORE_API_KEY_ID" --apiIssuer "$APPSTORE_API_ISSUER_ID"
echo "Upload submitted. Confirm TestFlight processing and tester eligibility in App Store Connect."