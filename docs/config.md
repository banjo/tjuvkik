# Config

`~/.config/tjuvkik/config.jsonc`, with every setting at its default:

```jsonc
{
  "$schema": "./schemas/config.schema.json",
  "view": "bento",
  "layout": "framed",
  "theme": "dark-glass",
  "trigger": { "key": "fn", "mode": "hold", "holdMs": 250 },
  "launchAtLogin": true,
  "menuBar": null,
  "pause": { "whenLocked": true, "onLowPower": true },
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
| `trigger` | `{ "key": "fn" }` | What opens the glance. See [Trigger](#trigger). |
| `launchAtLogin` | `true` | Start Tjuvkik when you log in. If macOS asks for approval, the menu links to Login Items. |
| `menuBar` | none | Panels from `panels` to show in the menu bar: `"agents"` or `["agents", "github"]`. |
| `pause` | both `true` | When background runs stop. See [Pause](#pause). |
| `panels` | `[]` | Which panels to show, in order. |

## Trigger

Hold a modifier key on its own:

```jsonc
"trigger": { "key": "fn", "holdMs": 250 }
```

Or press a shortcut:

```jsonc
"trigger": { "shortcut": "⌃⌥Space" }
```

- `key`: `fn`, `rightOption`, `rightCommand`, `rightControl` or `rightShift`. Pressed with another key or modifier, it doesn't open the glance, so fn+arrows and ⌥+letters still work. Needs Input Monitoring.
- `shortcut`: `"⌃⌥Space"`, `"ctrl+option+space"`, `"cmd+shift+g"`. It needs ⌃, ⌥ or ⌘, except F1–F20, which work alone. Keys are named by their place on a US keyboard. Tjuvkik takes the shortcut from other apps, and needs no permission for it. If another app already has it, the menu says so.
- `mode`: `hold` shows the glance while you hold, `toggle` shows it on a tap or press and hides it on the next one or Esc. A key holds by default, a shortcut toggles.
- `holdMs`: how long to hold before the glance shows, 50–2000. Default 250. Only with `hold`.

Set `key` or `shortcut`, not both. Caps Lock can't be a key, since macOS locks it on press. To use it, map it to F18 (with [hidutil](https://developer.apple.com/library/archive/technotes/tn2450/) or Karabiner-Elements) and set `"shortcut": "F18"`.

## Panels

```jsonc
"panels": [
  { "panel": "agents", "size": "xl" },
  { "panel": "github" },
]
```

- `panel`: a folder in `panels/`. See [Panels](panels.md).
- `size`: overrides the panel's own size. Optional.
- `background`: overrides the panel's own, for when it runs while the glance is closed: `true`, `false` or a duration like `"5m"`. See [Background](panels.md#background).
- `show`: `false` runs the panel for the menu bar without giving it a spot on the grid. Optional.

Panels fill a 4×3 grid in order:

| Size | Columns × rows |
|---|---|
| `s` | 1 × 1 |
| `m` | 2 × 1 |
| `l` | 2 × 2 |
| `xl` | 2 × 3 |

Panels that don't fit are left out, and the menu says which.

## Pause

```jsonc
"pause": { "whenLocked": true, "onLowPower": true }
```

- `whenLocked`: stop background runs while the screen is locked or the displays sleep.
- `onLowPower`: stop them while Low Power Mode is on.

The glance always runs panels on their `every`, whatever `pause` says. Coming back from a pause runs whatever is overdue, so the first glance after you unlock is never stale.

## Menu bar

```jsonc
"menuBar": ["agents", "github"]
```

Each panel decides what it shows, with [`menuBar` in its output](script-output.md#menu-bar): an icon and text in the menu bar, like `❓ 2  👀 3`, and its own rows in the menu. When no panel shows anything, the menu bar shows the grid icon. A broken config shows a warning sign.

## Files

- `.jsonc` and `.json` both work. If both exist, `.jsonc` wins.
- `$schema` gives completion and checks in editors that read it. Tjuvkik keeps `schemas/` up to date.
