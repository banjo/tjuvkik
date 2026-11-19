# Config

The settings window (Settings…, ⌘,) writes this file for you. It changes only the lines it needs to and keeps your comments, and it removes a setting that's back at its default. Anything it doesn't cover stays in the file as you wrote it.

`~/.config/tjuvkik/config.jsonc`, with every setting at its default:

```jsonc
{
  "$schema": "./schemas/config.schema.json",
  "view": "bento",
  "layout": "framed",
  "theme": "dark-glass",
  "trigger": { "key": "fn", "mode": "hold", "holdMs": 250, "closeOnClickOutside": true },
  "launchAtLogin": true,
  "grid": "4x3",
  "zoom": "auto",
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
- `mode`: `hold` shows the glance while you hold, `toggle` shows it on a tap or press and hides it on the next one or Esc. A key held longer than 400 ms isn't a tap, so using it as a modifier (fn+volume) doesn't toggle. `doubleTap`: two taps of the key, the second within `doubleTapMs`, show the glance; two more or Esc hide it. A single tap does nothing. Keys only. A key holds by default, a shortcut toggles.
- `holdMs`: how long to hold before the glance shows, 50–2000. Default 250. Only with `hold`.
- `doubleTapMs`: how soon the second tap must follow the first, 150–600. Default 300. Only with `doubleTap`.
- `closeOnClickOutside`: a click outside the open glance, or between its tiles, closes it. Default `true`.

Or double-tap a key:

```jsonc
"trigger": { "key": "rightCommand", "mode": "doubleTap" }
```

With fn, macOS may start dictation on a double tap. Change the dictation shortcut in System Settings → Keyboard → Dictation, or use another key.

Set `key` or `shortcut`, not both. Caps Lock can't be a key, since macOS locks it on press. To use it, map it to F18 (with [hidutil](https://developer.apple.com/library/archive/technotes/tn2450/) or Karabiner-Elements) and set `"shortcut": "F18"`.

### Pinning

- In `hold` mode, click the glance or press Space while you hold to keep it open after you let go.
- `toggle` and `doubleTap` stay open on their own.
- Esc, the trigger again, a click outside (unless `closeOnClickOutside` is `false`), or switching Space or app closes it.
- With right ⌘, ⌘Space may belong to Spotlight, so click instead.

The glance takes clicks whenever it's open, but never takes keyboard focus from the app in front.

### Keyboard

While the glance stays open (toggled, or pinned), a row is outlined, and you can use it without the mouse:

| Key | |
|---|---|
| ← → ↑ ↓ | The nearest row in that direction, across tiles. A tile without clickable rows is picked as a whole. |
| Enter or Space | What clicking the row does. |
| ⌥Enter | Open the row's `url`, when it also has a `command`. |
| ⌘K | List everything you can do with the row, including its [actions](script-output.md#row-actions). Arrows and Enter pick; Esc closes the list. |
| ⌘ and a key | The row's action with that `key`. |
| ⌘C | Copy the row's `url`, or its title. |
| ⌘R | Run the row's panel now. The glance stays open, so you see the result. |
| ⌘O | Open its `panel.jsonc`. |
| 1–9 | The first row of that tile, in `panels` order. |

A bar under the board shows the keys for the picked row.

When the glance opens, the first row picked is an error row, then a warning row, in a tile with `"focus": true`; then one anywhere; then the first row of a `focus` tile; then the first row. The keys are taken from the app in front only while the glance is open.

## Panels

```jsonc
"panels": [
  { "panel": "agents", "size": "2x3" },
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
- `focus`: `true` picks this tile first when you use the keyboard. See [Keyboard](#keyboard). Optional.
- `notify`: overrides the panel's own, key by key: `false`, `true` or an object. See [Notifications](notifications.md#a-panels-notify).

The same panel can be on the board more than once; give each an `id`:

```jsonc
"panels": [
  { "panel": "ci", "id": "ci-app",  "title": "CI · app",  "options": { "repo": "banjo/tjuvkik" } },
  { "panel": "ci", "id": "ci-dots", "title": "CI · dots", "options": { "repo": "banjo/dotfiles", "limit": 5 } },
]
```

A tile's `size` is columns x rows, like `"2x1"`, and panels fill the [grid](#grid-and-zoom) in order. Each content type has three layouts, picked by the shape:

| Size | Layout |
|---|---|
| `"1x1"` | A single cell: the one thing that matters most. |
| `"2x1"`, `"4x1"`, … | One row high, however wide: a strip, like a timeline across the board. |
| `"2x2"`, `"1x3"`, … | Taller, a single column included: the full layout, like a long list down the board's side. |

Lists too long for their tile scroll an item at a time: press ↓ on the last row in view, or use the trackpad or mouse wheel over the tile. A `↓ 5` in its corner says how many are left.

Panels that don't fit are left out, and the menu says which. The older size names still work: `s` is `"1x1"`, `m` `"2x1"`, `l` `"2x2"` and `xl` `"2x3"`.

## Grid and zoom

```jsonc
"grid": "6x4",
"zoom": "auto",
```

- `grid`: how many cells the board has, columns x rows. 2–8 columns and 3–6 rows. Default: `"4x3"`. A cell is the same size on every grid, so a bigger grid fits more panels and makes the glance bigger, and each panel looks the same.
- `zoom`: how big the glance draws everything, text included. `"auto"` is 1 on a laptop and grows on wider screens, up to 1.5. A number from 0.75 to 2 is fixed. Default: `"auto"`.

On a screen the board doesn't fit, it's drawn smaller, so a big grid can get small on a laptop. The panels stay where they are on every screen.

Settings → Board sets both.

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
