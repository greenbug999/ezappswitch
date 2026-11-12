#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK_ROOT="${ORBIT_WORK_ROOT:-$PWD/.artifacts}"
BUILD_ROOT="$WORK_ROOT/release-build"
CACHE_ROOT="$WORK_ROOT/cache"
STAGE="$WORK_ROOT/package"
OUTPUT="${ORBIT_OUTPUT_ROOT:-$PWD/dist}"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_ROOT/clang"
mkdir -p "$OUTPUT" "$STAGE" "$CACHE_ROOT/clang" "$CACHE_ROOT/config" "$CACHE_ROOT/security" "$CACHE_ROOT/swiftpm"
COMMON=(--disable-sandbox --scratch-path "$BUILD_ROOT" --cache-path "$CACHE_ROOT/swiftpm" --config-path "$CACHE_ROOT/config" --security-path "$CACHE_ROOT/security")
swift run "${COMMON[@]}" OrbitCoreChecks
swift build "${COMMON[@]}" -c release --product Orbit --arch arm64
swift build "${COMMON[@]}" -c release --product Orbit --arch x86_64
APP="$STAGE/ezappswitch.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$BUILD_ROOT/arm64-apple-macosx/release/Orbit" "$BUILD_ROOT/x86_64-apple-macosx/release/Orbit" -output "$APP/Contents/MacOS/Orbit"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>ezappswitch</string>
<key>CFBundleDisplayName</key><string>ezappswitch</string>
<key>CFBundleExecutable</key><string>Orbit</string>
<key>CFBundleIdentifier</key><string>local.qinghuan.launcher</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
swiftc scripts/make-icon.swift -o "$WORK_ROOT/make-icon"
"$WORK_ROOT/make-icon" "$WORK_ROOT/icons"
ICONSET="$WORK_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    cp "$WORK_ROOT/icons/$SIZE.png" "$ICONSET/icon_${SIZE}x${SIZE}.png"
    DOUBLE=$((SIZE * 2))
    cp "$WORK_ROOT/icons/$DOUBLE.png" "$ICONSET/icon_${SIZE}x${SIZE}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier local.qinghuan.launcher "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
lipo -info "$APP/Contents/MacOS/Orbit"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/ezappswitch-1.2.0-macOS-universal.zip"
ln -sfn /Applications "$STAGE/Applications"
cp README.txt "$STAGE/Getting-Started.txt"
hdiutil create -volname "ezappswitch" -srcfolder "$STAGE" -ov -format UDZO "$OUTPUT/ezappswitch-1.2.0-macOS-universal.dmg"
cp README.txt "$OUTPUT/ezappswitch-Getting-Started.txt"
printf 'Built: %s\n' "$OUTPUT/ezappswitch-1.2.0-macOS-universal.dmg"
