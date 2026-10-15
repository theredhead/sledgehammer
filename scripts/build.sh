#!/bin/zsh
set -eu
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/work/cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
swift build -c release --disable-sandbox --build-system native
swift scripts/icon.swift work/TrustMe.iconset
python3 scripts/pack-icon.py
APP="$PWD/outputs/Trust Me.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TrustMe "$APP/Contents/MacOS/TrustMe"
mkdir -p "$APP/Contents/Resources"
cp resources/TrustMe.icns "$APP/Contents/Resources/"
cp resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "$APP"
