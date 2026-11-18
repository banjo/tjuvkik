#!/bin/sh
# Releases the version in Resources/Info.plist: builds and signs Tjuvkik.app, uploads it as a
# GitHub release on banjo/tjuvkik and points the cask in banjo/homebrew-tap at it.
set -eu
cd "$(dirname "$0")/.."

repo=banjo/tjuvkik
tap=banjo/homebrew-tap

version=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
tag="v$version"

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first" >&2
  exit 1
fi
if gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  echo "$tag is already released. Bump CFBundleShortVersionString in Resources/Info.plist" >&2
  exit 1
fi
git push origin HEAD

scripts/build-app.sh
codesign --verify --strict build/Tjuvkik.app

zip="build/Tjuvkik-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent build/Tjuvkik.app "$zip"
sha=$(shasum -a 256 "$zip" | cut -d ' ' -f 1)

gh release create "$tag" "$zip" -R "$repo" --target "$(git rev-parse HEAD)" \
  --title "$tag" --generate-notes

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
gh repo clone "$tap" "$tmp" -- --quiet
mkdir -p "$tmp/Casks"
cat > "$tmp/Casks/tjuvkik.rb" <<EOF
cask "tjuvkik" do
  version "$version"
  sha256 "$sha"

  url "https://github.com/$repo/releases/download/v#{version}/Tjuvkik-#{version}.zip"
  name "Tjuvkik"
  desc "Hold fn to glance at your coding agents"
  homepage "https://tjuvkik.banjoanton.com"

  depends_on macos: ">= :sequoia"
  depends_on arch: :arm64

  app "Tjuvkik.app"
  binary "#{appdir}/Tjuvkik.app/Contents/MacOS/Tjuvkik", target: "tjuvkik"

  # Signed with a self-signed certificate, not notarized, so Gatekeeper would block it.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Tjuvkik.app"]
  end

  uninstall quit: "se.banjo.tjuvkik"
end
EOF
git -C "$tmp" add Casks/tjuvkik.rb
git -C "$tmp" commit --quiet -m "tjuvkik $version"
git -C "$tmp" push --quiet

echo "Released $tag: brew install --cask $tap/tjuvkik" | sed 's|/homebrew-|/|'
