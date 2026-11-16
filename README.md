# Tjuvkik

Hold fn to glance at your coding agents and anything else you plug in. Let go to close it.

## Install

Needs macOS 15 and the Xcode Command Line Tools.

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik Dev" code signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Every build is signed with the same certificate, so macOS keeps its permissions across rebuilds.

Then, once:

1. **Input Monitoring.** Tjuvkik asks on first start. Turn it on in System Settings → Privacy & Security → Input Monitoring. The menu bar icon has a shortcut there until it's granted.
2. **The 🌐 key.** In System Settings → Keyboard, set "Press 🌐 key to" to "Do nothing". Otherwise a tap switches input source and a double tap starts dictation.

Hold fn for a moment to glance; let go to close. fn together with another key (fn+arrows, fn+F-keys) doesn't open it.

## Development

```sh
swift build
swift test
```

See [PLAN.md](PLAN.md) for the v1 plan and [design/prototype.html](design/prototype.html) for the design.
