#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
VENDOR_DIR="$BUILD_DIR/vendor"
APP="$DIST_DIR/统一视频下载器.app"
mkdir -p "$VENDOR_DIR" "$DIST_DIR" "$BUILD_DIR/cache"

fetch_checked() {
  local url="$1" out="$2" expected="$3"
  if [ ! -f "$out" ]; then curl --fail --location --silent --show-error "$url" -o "$out"; fi
  local actual
  actual="$(shasum -a 256 "$out" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then echo "SHA-256 mismatch: $out" >&2; exit 1; fi
}

fetch_checked 'https://github.com/JoeanAmier/TikTokDownloader/releases/download/5.8/DouK-Downloader_V5.8_macOS_ARM64.zip' "$VENDOR_DIR/douk.zip" 'e989a85dee260c606c5a048be0fb8d34dbbff38969cdf99c3bedd9764ec5a28c'
fetch_checked 'https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp_macos' "$VENDOR_DIR/yt-dlp_macos" '0f922c15ccc0b83eefa1c8bc9104e434318c4bf16e408e1ee93b7745a6efe0aa'
fetch_checked 'https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2/ffmpeg.zip' "$VENDOR_DIR/ffmpeg.zip" 'c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924'

rm -rf "$APP" "$BUILD_DIR/douk" "$BUILD_DIR/ffmpeg"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/douk" "$BUILD_DIR/ffmpeg"
unzip -q "$VENDOR_DIR/douk.zip" -d "$APP/Contents/Resources/douk"
unzip -q "$VENDOR_DIR/ffmpeg.zip" -d "$BUILD_DIR/ffmpeg"
cp "$VENDOR_DIR/yt-dlp_macos" "$APP/Contents/Resources/yt-dlp_macos"
cp "$BUILD_DIR/ffmpeg/ffmpeg" "$APP/Contents/Resources/ffmpeg"
cp "$PROJECT_DIR/macos/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_DIR/docs/Mac-使用指南.txt" "$APP/Contents/Resources/使用指南.txt"
cp "$PROJECT_DIR/docs/THIRD_PARTY.txt" "$APP/Contents/Resources/第三方组件与源码说明.txt"
cp "$PROJECT_DIR/LICENSE" "$APP/Contents/Resources/LICENSE"
sips -s format icns "$PROJECT_DIR/macos/AppIcon.png" --out "$APP/Contents/Resources/AppIcon.icns" >/dev/null
chmod +x "$APP/Contents/Resources/douk/DouK-Downloader" "$APP/Contents/Resources/yt-dlp_macos" "$APP/Contents/Resources/ffmpeg"

SDK_PATH='/Library/Developer/CommandLineTools/SDKs/MacOSX13.1.sdk'
if [ ! -d "$SDK_PATH" ]; then SDK_PATH="$(xcrun --show-sdk-path)"; fi
swiftc -sdk "$SDK_PATH" -module-cache-path "$BUILD_DIR/cache" "$PROJECT_DIR/macos/App.swift" -o "$APP/Contents/MacOS/UnifiedVideoDownloader" -framework AppKit
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

(cd "$DIST_DIR" && zip -qry 'VideoDownloader-macOS-AppleSilicon.zip' '统一视频下载器.app')
echo "Built $DIST_DIR/VideoDownloader-macOS-AppleSilicon.zip"
echo 'This is an ad-hoc signed developer build. Public distribution requires Developer ID signing and Apple notarization.'
