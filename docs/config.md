# Config

`~/.config/tjuvkik/config.jsonc`, with every setting at its default:

```jsonc
{
  "$schema": "./schemas/config.schema.json",
  "view": "bento",
  "layout": "framed",
  "theme": "dark-glass",
  "trigger": { "holdMs": 250 },
  "launchAtLogin": true,
  "menuBar": null,
  "panels": [
    { "panel": "disk" },
  ],
}
```

Saved changes apply within a second. Comments and trailing commas are fine. If a change breaks something, Tjuvkik keeps the last working config and lists the errors in the menu bar menu.

## Settings

| Key | Default | |
|---|---|---|
| `view` | `"bento"` | Only `bento` for now. |
| `layout` | `"framed"` | Only `framed` for now. |
| `theme` | `"dark-glass"` | `dark-glass`, `light-glass`, `dracula`, or a file in `themes/`. See [Themes](themes.md). |
| `trigger.holdMs` | `250` | How long to hold fn before the glance opens, 50–2000. |
| `launchAtLogin` | `true` | Start Tjuvkik when you log in. If macOS asks for approval, the menu links to Login Items. |
| `menuBar` | none | Panels from `panels` to show in the menu bar: `"agents"` or `["agents", "github"]`. |
| `panels` | `[]` | Which panels to show, in order. |

## Panels

```jsonc
"panels": [
  { "panel": "agents", "size": "xl" },
  { "panel": "github" },
]
```

- `panel`: a folder in `panels/`. See [Panels](panels.md).
- `size`: overrides the panel's own size. Optional.

Panels fill a 4×3 grid in order:

| Size | Columns × rows |
|---|---|
| `s` | 1 × 1 |
| `m` | 2 × 1 |
| `l` | 2 × 2 |
| `xl` | 2 × 3 |

Panels that don't fit are left out, and the menu says which.

## Menu bar

```jsonc
"menuBar": ["agents", "github"]
```

Each panel decides what it shows, with [`menuBar` in its output](script-output.md#menu-bar): an icon and text in the menu bar, like `❓ 2  👀 3`, and its own rows in the menu. When no panel shows anything, the menu bar shows the grid icon. A broken config shows a warning sign.

## Files

- `.jsonc` and `.json` both work. If both exist, `.jsonc` wins.
- `$schema` gives completion and checks in editors that read it. Tjuvkik keeps `schemas/` up to date.
