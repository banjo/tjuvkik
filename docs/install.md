# Install

```sh
scripts/create-cert.sh   # once: a self-signed "Tjuvkik Dev" signing certificate
scripts/bundle.sh --open # build, sign, install to ~/Applications and start
```

Needs macOS 15 and the Xcode Command Line Tools. It also links the [command line tool](cli.md) to `~/.local/bin/tjuvkik`. Every build is signed with the same certificate, so macOS keeps the permissions across rebuilds.

## Once

1. **Input Monitoring.** Tjuvkik asks on first start. Turn it on in System Settings → Privacy & Security → Input Monitoring.
2. **The 🌐 key.** In System Settings → Keyboard, set "Press 🌐 key to" to "Do nothing". Otherwise a tap switches input source. With fn, macOS may start dictation on a double tap. Change the dictation shortcut in System Settings → Keyboard → Dictation, or use another key.

## Use

Hold fn to glance, let go to close. fn with another key (fn+arrows, fn+F-keys) doesn't open it. The glance opens on the screen of the window you're in.

No fn key, or using it for something else? Pick right ⌥, right ⌘ or a shortcut like ⌃⌥Space as the [trigger](config.md#trigger).

## First start

On first start Tjuvkik writes a default config to `~/.config/tjuvkik/` and opens a short setup, four steps you can each skip:

1. **Trigger:** the key or shortcut, and hold, toggle or double tap. Try it right there.
2. **Panels:** tick [starter panels](panels.md#starter-panels), with a miniature of your board.
3. **Theme:** pick one from previews of your board.
4. **Done:** launch at login, background runs and notifications. Done shows the glance once.

Each step writes to `config.jsonc` straight away, so quitting halfway leaves a working config. "Set Up…" in the menu opens it again. A config folder that's already there, say from your dotfiles, skips it.

Next: [Config](config.md).
