# Themes

Pick one in `config.jsonc`:

```jsonc
"theme": "dark-glass"   // or "light-glass", "dracula", or a file in themes/
```

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
}
```

Usually a few lines are enough:

```jsonc
{ "extends": "dracula", "accent": "#ff79c6", "radius": 14 }
```

Then set `"theme": "<name>"` in `config.jsonc`.

## Settings

| Key | |
|---|---|
| `extends` | A built-in theme or another file in `themes/`. Default `dark-glass`. |
| `appearance` | `dark` or `light`. |
| `blur` | Blur what's behind the tiles. Without it, `panel` is drawn solid. |
| `radius` | Tile corner radius, 0–40. |
| `panel` | Tile background. |
| `well` | Inset backgrounds. |
| `text`, `secondaryText`, `tertiaryText` | Text, from strongest to faintest. |
| `line` | Borders and dividers. |
| `warning`, `error`, `success`, `info`, `accent` | The [tones](script-output.md#tones). `muted` uses `tertiaryText`, and `normal` keeps the default color. |

Colors are `#rgb`, `#rrggbb` or `#rrggbbaa`.
