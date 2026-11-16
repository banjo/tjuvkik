# Tjuvkik

Hold fn to glance at your coding agents and anything else you plug in. Let go to close it.

## Install

Needs macOS 15 and the Xcode Command Line Tools.

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik Dev" code signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Every build is signed with the same certificate, so macOS keeps its permissions across rebuilds.

## Development

```sh
swift build
swift test
```

See [PLAN.md](PLAN.md) for the v1 plan and [design/prototype.html](design/prototype.html) for the design.
