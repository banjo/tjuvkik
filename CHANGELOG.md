# tjuvkik

## 0.1.2

### Patch Changes

- 54cecdf: `"dim": true` in config.jsonc darkens the screen behind the glance, or a number from 0 to 1 for how much. Settings → General → Glance sets it too.
- 54cecdf: `"focusOnOpen": "last"` opens the glance on the row you were on when it closed, instead of the most urgent one. Settings → General → Glance sets it too.
- 54cecdf: The bar with the keyboard shortcuts sits right under the lowest tile, not under empty rows of the grid.
- d54de7f: A tile's size is now columns x rows, like `"2x1"`, `"3x1"` for a wide strip or `"1x2"` for a tall one. The old names `s`, `m`, `l` and `xl` still work. Long lists scroll: press ↓ on the last row in view, or use the trackpad or mouse wheel over the tile, and a small "↓ 5" shows what's left below.
