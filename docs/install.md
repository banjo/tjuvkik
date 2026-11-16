# Install

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik Dev" signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Needs macOS 15 and the Xcode Command Line Tools. Every build is signed with the same certificate, so macOS keeps the permissions across rebuilds.

## Once

1. **Input Monitoring.** Tjuvkik asks on first start. Turn it on in System Settings → Privacy & Security → Input Monitoring.
2. **The 🌐 key.** In System Settings → Keyboard, set "Press 🌐 key to" to "Do nothing". Otherwise a tap switches input source.

## Use

Hold fn to glance, let go to close. fn with another key (fn+arrows, fn+F-keys) doesn't open it. The glance opens on the screen of the window you're in.

On first start Tjuvkik writes a default config to `~/.config/tjuvkik/`. Next: [Config](config.md).
