#!/bin/bash
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
set -e

APP_NAME="HotkeyDetector"
# SPM build output directory (release)
BUILD_DIR=".build/release"
# Artifacts output directory
OUTPUT_DIR=".build"
mkdir -p "${OUTPUT_DIR}"

APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
DMG_NAME="${OUTPUT_DIR}/${APP_NAME}.dmg"
DMG_TEMP_DIR="${OUTPUT_DIR}/dmg_temp"

echo "🚀 Building ${APP_NAME}..."
swift build -c release

echo "📦 Packaging App..."
# Clean previous build
rm -rf "${APP_BUNDLE}" || true

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy Icon
ICON_SOURCE="Sources/HotkeyDetector/Resources/AppIcon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo "  - Processing icon..."
    cp "$ICON_SOURCE" "${APP_BUNDLE}/Contents/Resources/AppIcon.png"
    
    # Optimize: Convert PNG to ICNS if sips is available (it should be on macOS)
    # Using sips to create a basic icns from the png
    sips -s format icns "$ICON_SOURCE" --out "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" > /dev/null 2>&1 || true
fi

# Create Info.plist
echo "  - Generating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.minzhiwei.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permission
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "📀 Creating DMG Installer..."
# Cleanup DMG temp
rm -rf "${DMG_TEMP_DIR}" "${DMG_NAME}" || true
mkdir -p "${DMG_TEMP_DIR}"

# Copy App to DMG folder
cp -r "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"

# Create /Applications link
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG
echo "  - Compressing disk image..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_NAME}"

# Cleanup temp dir
rm -rf "${DMG_TEMP_DIR}"

echo "✅ Build completed!"
echo "  - App: ${PWD}/${APP_BUNDLE}"
echo "  - DMG: ${PWD}/${DMG_NAME}"
