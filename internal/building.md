# Building Tjuvkik

For working on the app itself. The user docs are in [docs/](../docs).

## Build and install

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik" signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Releases are signed with the same certificate, so it must never change: macOS ties Input Monitoring to it, and a new one makes every user grant it again. `create-cert.sh` writes a backup to `~/Downloads/Tjuvkik.p12` and prints its password; keep both in Bitwarden. On a new machine, download the backup and import it with `scripts/create-cert.sh Tjuvkik.p12`.

Needs macOS 15 and the Xcode Command Line Tools. `bundle.sh` builds a release `Tjuvkik.app`, installs it to `~/Applications` and links the command line tool, the app's own binary, to `~/.local/bin/tjuvkik`. Every build is signed with the same certificate, so macOS keeps the permissions, like Input Monitoring, across rebuilds.

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
