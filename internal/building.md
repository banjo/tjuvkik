# Building Tjuvkik

For working on the app itself. The user docs are in [docs/](../docs).

## Build and install

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik" signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Releases are signed with the same certificate, so it must never change: macOS ties Input Monitoring to it, and a new one makes every user grant it again. `create-cert.sh` writes a backup to `~/Downloads/Tjuvkik.p12` and prints its password; keep both in Bitwarden. They're in the secure note "Tjuvkik signing certificate": the backup base64 encoded as the note, the password as its `password` field. On a new machine:

```sh
bw get notes "Tjuvkik signing certificate" | base64 -d > Tjuvkik.p12
bw get item "Tjuvkik signing certificate" | jq -r '.fields[] | select(.name == "password") | .value'
scripts/create-cert.sh Tjuvkik.p12   # asks for that password
rm Tjuvkik.p12
```

Needs macOS 15 and the Xcode Command Line Tools. `bundle.sh` builds a release `Tjuvkik.app`, installs it to `~/Applications` and links the command line tool, the app's own binary, to `~/.local/bin/tjuvkik`. Every build is signed with the same certificate, so macOS keeps the permissions, like Input Monitoring, across rebuilds.

## Release

```sh
scripts/release.sh
```

Releases the version in `Resources/Info.plist`, so bump `CFBundleShortVersionString` first. While Tjuvkik is in 0.x, every release bumps the minor: 0.1.0, 0.2.0, 0.3.0. It builds and signs `Tjuvkik.app`, uploads it zipped as a GitHub release on `banjo/tjuvkik` and writes the cask in [banjo/homebrew-tap](https://github.com/banjo/homebrew-tap) with the new version and checksum. Needs a clean working tree and `gh` logged in as an account that can push to both repos.

The app isn't notarized, so the cask removes the quarantine flag after installing; without it Gatekeeper blocks the app. It's built for Apple silicon only: a universal build needs full Xcode.

## Test

```sh
swift build
swift test
```

## Previews in the docs

Every page in `docs/types/` shows its first JSON example as the app draws it, at s, m and l, from `docs/types/images/`. After changing an example or how a type draws, install the app with `scripts/bundle.sh` and run:

```sh
scripts/docs-previews.py          # every type
scripts/docs-previews.py chart    # just one
```

It renders each example with `tjuvkik preview` in the dark-glass theme. Times in the timeline and feed examples are moved to the moment it runs, so they read as written.

## App icon

The icon is drawn in `Resources/AppIcon.svg`. After changing it, run `scripts/make-icon.sh` (needs `brew install librsvg`) to write `Resources/AppIcon.icns`.

## Design

See [PLAN.md](../PLAN.md) for the v1 plan and [design/prototype.html](../design/prototype.html) for the design.
