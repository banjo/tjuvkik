#!/bin/sh
# Builds a release Tjuvkik.app, signs it with "Tjuvkik" and installs it to ~/Applications.
set -eu
cd "$(dirname "$0")/.."

scripts/build-app.sh
app=build/Tjuvkik.app

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
