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
    { "panel": "agents", "size": "xl" },   // panels/agents/
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

A panel is a folder in `panels/` with a `panel.jsonc`. Tjuvkik has no built-in panels: everything, agents included, is a folder you can copy, share or write yourself.

```jsonc
{
  "description": "Pull requests waiting for your review",   // optional metadata
  "author": "banjo",
  "version": "1.0.0",
  "requires": ["gh", "jq"],      // checked on PATH; the tile says what's missing
  "type": "script",              // or "cli"
  "mode": "interval",            // or "stream"
  "title": "GitHub",
  "command": "./github.sh",      // /bin/sh -c in this folder, with your login shell's PATH
  "every": "5m",                 // interval panels: how often, at least 5s
  "timeout": "20s",              // interval panels: how long a run may take
  "size": "l",
}
```

- **`cli`** shows the command's output as is, color codes removed, as many lines as fit.
- **`script`** prints JSON, which the tile shows as rows (below).
- **`interval`** runs the command every `every`. If a run fails, the tile keeps what it last showed, marks it stale and shows the error.
- **`stream`** keeps the command running. A script prints a new JSON document per line whenever something changes, and the tile updates at once; a cli panel shows the latest lines, like `tail -f`. If it exits, it's restarted after 1s, backing off to 30s.

A script's JSON:

```jsonc
{
  "hero": { "value": "2", "label": "reviews requested", "tone": "warning" },  // optional
  "summary": [{ "icon": "❓", "value": "2", "label": "waiting", "tone": "warning" }],  // optional
  "progress": 0.62,                                                            // optional, 0 to 1
  "rows": [
    {
      "icon": "👀", "title": "Export bookings", "subtitle": "logbook #1284", "trailing": "1h",
      "tone": "warning",
      "group": "Reviews",                   // optional heading over each run of rows in a group
      "note": "Bash: rm -rf node_modules"   // optional line under the row, for what needs you
    }
  ]
}
```

Everything but `rows` and each row's `title` is optional. `tone` is `normal`, `muted`, `warning`, `error`, `success`, `info` or `accent`; the theme picks the color.

Examples in [examples/panels](examples/panels):

- [`agents`](examples/panels/agents): coding agents from [agent-watcher](https://github.com/banjo/dotfiles/tree/master/.config/agent-watcher), streamed with `agent-watcher list --json --watch`.
- [`github`](examples/panels/github): pull requests waiting for your review, then yours, with `gh`.

## Development

```sh
swift build
swift test
```

The app icon is drawn in `Resources/AppIcon.svg`. After changing it, run `scripts/make-icon.sh` (needs `brew install librsvg`) to write `Resources/AppIcon.icns`.

See [PLAN.md](PLAN.md) for the v1 plan and [design/prototype.html](design/prototype.html) for the design.
