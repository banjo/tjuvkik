#!/bin/sh
# Builds a release build/Tjuvkik.app and signs it with "Tjuvkik".
set -eu
cd "$(dirname "$0")/.."

swift build -c release
bin=$(swift build -c release --show-bin-path)

app=build/Tjuvkik.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
cp -R schema "$app/Contents/Resources/schemas"
cp -R starters "$app/Contents/Resources/starters"
cp "$bin/Tjuvkik" "$app/Contents/MacOS/"

codesign --force --options runtime --sign "Tjuvkik" "$app"
