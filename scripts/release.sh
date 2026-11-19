#!/bin/sh
# Releases the changesets in .changeset/: bumps the version, writes CHANGELOG.md and commits that,
# then builds and signs Tjuvkik.app, uploads it as a GitHub release on banjo/tjuvkik with the
# changelog as its notes, and points the cask in banjo/homebrew-tap at it.
set -eu
cd "$(dirname "$0")/.."

repo=banjo/tjuvkik
tap=banjo/homebrew-tap

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first" >&2
  exit 1
fi

# Changesets other than the README: turn them into a version, a changelog entry and a commit.
if ls .changeset/*.md 2>/dev/null | grep -qv '/README\.md$'; then
  pnpm install --silent --frozen-lockfile
  pnpm exec changeset version
  version=$(jq -r .version package.json)
  build=$(( $(plutil -extract CFBundleVersion raw Resources/Info.plist) + 1 ))
  plutil -replace CFBundleShortVersionString -string "$version" Resources/Info.plist
  plutil -replace CFBundleVersion -string "$build" Resources/Info.plist
  git add -A
  git commit --quiet -m "release $version"
fi

version=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
tag="v$version"

if gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  echo "$tag is already released. Add a changeset with 'pnpm changeset' first" >&2
  exit 1
fi
git push origin HEAD

# This version's section of CHANGELOG.md, without its heading.
notes=$(awk -v heading="## $version" '$0 == heading { on = 1; next } on && /^## / { exit } on' CHANGELOG.md 2>/dev/null || true)

scripts/build-app.sh
codesign --verify --strict build/Tjuvkik.app

zip="build/Tjuvkik-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent build/Tjuvkik.app "$zip"
sha=$(shasum -a 256 "$zip" | cut -d ' ' -f 1)

if [ -n "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
  gh release create "$tag" "$zip" -R "$repo" --target "$(git rev-parse HEAD)" --title "$tag" --notes "$notes"
else
  gh release create "$tag" "$zip" -R "$repo" --target "$(git rev-parse HEAD)" --title "$tag" --generate-notes
fi

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

  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "Tjuvkik.app"
  binary "#{appdir}/Tjuvkik.app/Contents/MacOS/Tjuvkik", target: "tjuvkik"

  # Signed with a self-signed certificate, not notarized, so Gatekeeper would block it.
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Tjuvkik.app"],
        writable_paths: ["{{appdir}}/Tjuvkik.app"]
  end

  uninstall quit: "se.banjo.tjuvkik"
end
EOF
git -C "$tmp" add Casks/tjuvkik.rb
git -C "$tmp" commit --quiet -m "tjuvkik $version"
git -C "$tmp" push --quiet

echo "Released $tag: brew install --cask $tap/tjuvkik" | sed 's|/homebrew-|/|'
