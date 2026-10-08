#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

CONFIG="${CONFIG:-release}"
APP_NAME="FileFlyfer"
APP_DIR="$ROOT/dist/$APP_NAME.app"
swift build --disable-sandbox -c "$CONFIG"
BIN_DIR="$(swift build --disable-sandbox -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BIN" ]]; then
  print -u2 "FileFlyfer executable bulunamadı: $BIN"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp Packaging/Info.plist "$APP_DIR/Contents/Info.plist"
cp Packaging/PkgInfo "$APP_DIR/Contents/PkgInfo"
cp Packaging/FileFlyfer.entitlements "$APP_DIR/Contents/FileFlyfer.entitlements"
cp Sources/FileFlyfer/Resources/ThirdPartyNotices.txt "$APP_DIR/Contents/Resources/ThirdPartyNotices.txt"

# Production builds must provide both architectures or use an architecture-specific binary.
if [[ -x "$ROOT/Vendor/platform-tools/adb" ]]; then
  cp "$ROOT/Vendor/platform-tools/adb" "$APP_DIR/Contents/Resources/adb"
  chmod 755 "$APP_DIR/Contents/Resources/adb"
else
  print -u2 "Uyarı: Vendor/platform-tools/adb bulunamadı; uygulama sistemdeki ADB'yi arayacak."
fi

IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$APP_DIR/Contents/FileFlyfer.entitlements" --sign "$IDENTITY" "$APP_DIR/Contents/MacOS/$APP_NAME"
  if [[ -f "$APP_DIR/Contents/Resources/adb" ]]; then
    codesign --force --options runtime --timestamp --entitlements "$ROOT/Packaging/ADBHelper.entitlements" --sign "$IDENTITY" "$APP_DIR/Contents/Resources/adb"
  fi
  codesign --force --options runtime --timestamp --entitlements "$APP_DIR/Contents/FileFlyfer.entitlements" --sign "$IDENTITY" "$APP_DIR"
else
  # Ad-hoc signing makes the manually assembled bundle LaunchServices-compatible
  # for local testing. It is not suitable for distribution.
  codesign --force --deep --sign - "$APP_DIR"
  print "İmzasız geliştirme paketi oluşturuldu: $APP_DIR"
fi

print "Hazır: $APP_DIR"
