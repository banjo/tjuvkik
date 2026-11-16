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

## Config

Everything is in `~/.config/tjuvkik/`, so you can keep it in your dotfiles:

```
config.jsonc               theme, fn, and which panels go where
panels/<name>/panel.jsonc  what a panel shows; its command runs in that folder
themes/<name>.jsonc        your own themes
```

The defaults are written on first run, and every file is reloaded within a second of saving. Comments and trailing commas are fine. Files end in `.jsonc` so editors accept the comments; `.json` works too. The `$schema` keys give completion in editors that read them. If an edit breaks something, Tjuvkik keeps the last good config and lists the errors in the menu bar menu.

```jsonc
// config.jsonc
{
  "theme": "mine",
  "panels": [
    { "panel": "agents", "size": "xl" },
    { "panel": "pods", "size": "m" },
  ],
}

// panels/pods/panel.jsonc
{ "type": "cli", "title": "Pods", "command": "kubectl get pods", "every": "30s" }

// themes/mine.jsonc
{ "extends": "dracula", "accent": "#ff79c6" }
```

Panels fill a 4×3 grid in order. Sizes: `s` 1×1, `m` 2×1, `l` 2×2, `xl` 2×3; a size in `config.jsonc` wins over the panel's own.

The menu bar menu can also export the folder as a zip and import one. Importing checks the zip first and backs up your current config to `~/Library/Application Support/Tjuvkik/Backups/`.

## Panels

A panel is a folder in `panels/` with a `panel.jsonc`. Its command runs with `/bin/sh -c` in that folder, with your login shell's `PATH`, on its interval (`every`, at least `5s`) and with a `timeout`. If a run fails, the tile keeps what it last showed, marks it stale and shows the error.

- **`cli`** shows the command's output as is, color codes removed, as many lines as fit.
- **`script`** prints JSON, and the tile shows it as rows:

```jsonc
{
  "hero": { "value": "2", "label": "reviews requested", "tone": "warning" }, // optional
  "progress": 0.62,                                                           // optional, 0 to 1
  "rows": [
    { "icon": "👀", "title": "Export bookings", "subtitle": "logbook #1284", "trailing": "1h", "tone": "warning" }
  ]
}
```

Everything but `rows` and each row's `title` is optional. `tone` is `normal`, `muted`, `warning`, `error`, `success`, `info` or `accent`; the theme picks the color. See [examples/panels/github](examples/panels/github) for a script panel using `gh`.

## Development

```sh
swift build
swift test
```

See [PLAN.md](PLAN.md) for the v1 plan and [design/prototype.html](design/prototype.html) for the design.
