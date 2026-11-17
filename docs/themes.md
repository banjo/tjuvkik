# Themes

Pick one in `config.jsonc`:

```jsonc
"theme": "dark-glass"   // or "light-glass", "dracula", or a file in themes/
```

## Light and dark

To follow the system's appearance, name one theme for light mode and one for dark. Set both:

```jsonc
"theme": { "light": "light-glass", "dark": "dracula" }
```

The glance switches while it's open, when you change System Settings → Appearance.

## Your own

`themes/<name>.jsonc` starts from another theme and changes what it sets. Every setting, as in `dark-glass`:

```jsonc
{
  "$schema": "../schemas/theme.schema.json",
  "extends": "dark-glass",
  "appearance": "dark",
  "blur": true,
  "radius": 16,
  "panel": "#1e1f298c",
  "well": "#00000047",
  "text": "#f8f8f2",
  "secondaryText": "#f8f8f294",
  "tertiaryText": "#f8f8f25c",
  "line": "#ffffff14",
  "warning": "#ffb86c",
  "error": "#ff6e6e",
  "success": "#50fa7b",
  "info": "#8be9fd",
  "accent": "#bd93f9",
  "material": "hud",
  "font": { "scale": 1 },
  "board": { "gap": 10, "inset": 10 },
  "tile": {
    "border": 1,
    "shadow": true,
    "padding": 12,
    "header": { "uppercase": false, "kind": true, "interval": true },
  },
}
```

Usually a few lines are enough:

```jsonc
{ "extends": "dracula", "accent": "#ff79c6", "radius": 14 }
```

Or more than colors:

```jsonc
// themes/terminal.jsonc
{
  "extends": "dracula",
  "radius": 4,
  "blur": true,
  "material": "popover",
  "font": { "family": "Inter", "mono": "JetBrains Mono", "scale": 1.1 },
  "board": { "gap": 6, "inset": 12 },
  "tile": {
    "border": 0,
    "shadow": false,
    "padding": 10,
    "header": { "uppercase": true, "kind": false, "interval": false },
  },
  "tones": { "error": { "background": "#ff55551a" } },
}
```

Then set `"theme": "<name>"` in `config.jsonc`.

Every setting is optional, and one a theme doesn't set comes from the theme it extends, key by key: a theme that sets `font.scale` keeps the `font.family` it extends.

## Settings

| Key | |
|---|---|
| `extends` | A built-in theme or another file in `themes/`. Default `dark-glass`. |
| `appearance` | `dark` or `light`. |
| `blur` | Blur what's behind the tiles. Without it, `panel` is drawn solid. |
| `radius` | Tile corner radius, 0–40. |
| `material` | The glass behind the tiles, while `blur` is on: `hud` (default), `popover`, `menu`, `sidebar` or `underWindow`. |
| `font.family` | The font for text, as Font Book names it. Default: the system font. |
| `font.mono` | The font for monospaced text. Default: the system's monospaced font. |
| `font.scale` | Multiplies every text size, 0.85–1.25. Default 1. |
| `board.gap` | Space between tiles, 0–24. Default 10. The board keeps its size, so the tiles grow or shrink. |
| `board.inset` | Space around the tiles, 0–40. Default 10. |
| `tile.border` | Width of the tile's outline, 0–4. Default 1; 0 is none. |
| `tile.shadow` | A shadow under each tile. Default `true`. |
| `tile.padding` | Space inside a tile, 6–20. Default 12. |
| `tile.header.uppercase` | Titles in upper case. Default `false`. |
| `tile.header.kind` | The type tag, like `table`. Default `true`. |
| `tile.header.interval` | How often it runs, like `every 1m` or `live`. Default `true`. `stale` always shows. |
| `tones.<tone>.background` | What's drawn behind pills, highlighted rows and table rows in that tone: `muted`, `warning`, `error`, `success`, `info` or `accent`. Default: the tone's color, faded. |
| `panel` | Tile background. |
| `well` | Inset backgrounds. |
| `text`, `secondaryText`, `tertiaryText` | Text, from strongest to faintest. |
| `line` | Borders and dividers. |
| `warning`, `error`, `success`, `info`, `accent` | The [tones](script-output.md#tones). `muted` uses `tertiaryText`, and `normal` keeps the default color. |

Colors are `#rgb`, `#rrggbb` or `#rrggbbaa`.

A font that isn't installed is a warning in the menu, and that text uses the system font.
