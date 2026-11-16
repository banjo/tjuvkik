#!/bin/sh
# Builds a release Tjuvkik.app, signs it with "Tjuvkik Dev" and installs it to ~/Applications.
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
cp "$bin/Tjuvkik" "$app/Contents/MacOS/"

codesign --force --options runtime --sign "Tjuvkik Dev" "$app"

dest="$HOME/Applications/Tjuvkik.app"
pkill -x Tjuvkik 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$dest"
cp -R "$app" "$dest"
echo "Installed $dest"

# The command line tool is the app's own binary.
bindir="$HOME/.local/bin"
mkdir -p "$bindir"
ln -sf "$dest/Contents/MacOS/Tjuvkik" "$bindir/tjuvkik"
echo "Linked $bindir/tjuvkik"
case ":$PATH:" in
  *":$bindir:"*) ;;
  *) echo "Add $bindir to your PATH to run tjuvkik" ;;
esac

if [ "${1:-}" = "--open" ]; then
  open "$dest"
fi
