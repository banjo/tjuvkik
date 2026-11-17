# Config

The settings window (Settings…, ⌘,) writes this file for you. It changes only the lines it needs to and keeps your comments, and it removes a setting that's back at its default. Anything it doesn't cover stays in the file as you wrote it.

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
| `theme` | `"dark-glass"` | `dark-glass`, `light-glass`, `dracula`, or a file in `themes/`. Or `{ "light": …, "dark": … }` to follow the system's appearance. See [Themes](themes.md#light-and-dark). |
| `trigger` | `{ "key": "fn" }` | What opens the glance. See [Trigger](#trigger). |
| `launchAtLogin` | `true` | Start Tjuvkik when you log in. If macOS asks for approval, the menu links to Login Items. |
| `menuBar` | none | Tiles from `panels`, by id, to show in the menu bar: `"agents"` or `["agents", "github"]`. |
| `pause` | both `true` | When background runs stop. See [Pause](#pause). |
| `notifications` | on | Sound, quiet hours and whether to notify while glancing. See [Notifications](#notifications). |
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
- `mode`: `hold` shows the glance while you hold, `toggle` shows it on a tap or press and hides it on the next one or Esc. `doubleTap`: two taps of the key, the second within `doubleTapMs`, show the glance; two more or Esc hide it. A single tap does nothing. Keys only. A key holds by default, a shortcut toggles.
- `holdMs`: how long to hold before the glance shows, 50–2000. Default 250. Only with `hold`.
- `doubleTapMs`: how soon the second tap must follow the first, 150–600. Default 300. Only with `doubleTap`.

Or double-tap a key:

```jsonc
"trigger": { "key": "rightCommand", "mode": "doubleTap" }
```

With fn, macOS may start dictation on a double tap. Change the dictation shortcut in System Settings → Keyboard → Dictation, or use another key.

Set `key` or `shortcut`, not both. Caps Lock can't be a key, since macOS locks it on press. To use it, map it to F18 (with [hidutil](https://developer.apple.com/library/archive/technotes/tn2450/) or Karabiner-Elements) and set `"shortcut": "F18"`.

## Panels

```jsonc
"panels": [
  { "panel": "agents", "size": "xl" },
  { "panel": "github" },
]
```

- `panel`: a folder in `panels/`. See [Panels](panels.md).
- `id`: the tile's name, for `menuBar` and `tjuvkik run`. Letters, digits, `-` and `_`. Default: `panel`.
- `title`: the tile's title; overrides the panel's own. Optional.
- `options`: values for the [options](panels.md#options) the panel declares.
- `size`: overrides the panel's own size. Optional.
- `background`: overrides the panel's own, for when it runs while the glance is closed: `true`, `false` or a duration like `"5m"`. See [Background](panels.md#background).
- `show`: `false` runs the panel for the menu bar without giving it a spot on the grid. Optional.
- `notify`: overrides the panel's own, key by key: `false`, `true` or an object. See [Notifications](notifications.md#a-panels-notify).

The same panel can be on the board more than once; give each an `id`:

```jsonc
"panels": [
  { "panel": "ci", "id": "ci-app",  "title": "CI · app",  "options": { "repo": "banjo/tjuvkik" } },
  { "panel": "ci", "id": "ci-dots", "title": "CI · dots", "options": { "repo": "banjo/dotfiles", "limit": 5 } },
]
```

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

## Notifications

```jsonc
"notifications": { "enabled": true, "sound": true, "quietHours": "22:00-07:00", "whileOpen": false }
```

- `enabled`: `false` turns off notifications from every panel.
- `sound`: play the system's notification sound.
- `quietHours`: nothing is delivered between these times, local time, like `"22:00-07:00"`.
- `whileOpen`: deliver while the glance is showing. Off by default.

See [Notifications](notifications.md) for how panels send them.

## Menu bar

```jsonc
"menuBar": ["agents", "github"]
```

`menuBar` lists tile ids: an entry's `id`, or its `panel` when it has none.

Each panel decides what it shows, with [`menuBar` in its output](script-output.md#menu-bar): an icon and text in the menu bar, like `❓ 2  👀 3`, and its own rows in the menu. When no panel shows anything, the menu bar shows the grid icon. A broken config shows a warning sign.

## Files

- `.jsonc` and `.json` both work. If both exist, `.jsonc` wins.
- `$schema` gives completion and checks in editors that read it. Tjuvkik keeps `schemas/` up to date.
