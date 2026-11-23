# tjuvkik

## 0.1.7

### Patch Changes

- 1b8e8f8: ⌘K no longer lists Copy Link twice when one of the row's actions already copies its link.
- 9b1f835: The picked row follows its row when a panel updates, also when its title or actions change, such as a terminal that starts working or gets pinned. Before, the pick stayed where it was and landed on another row.
- ad8408e: Spotlight: `"view": "spotlight"` opens a list instead of the board, with an All tab for every panel's rows and a tab per panel. Beside it, a preview shows the picked row in full, with what Enter does and its actions. A search field filters every tab as you type; turn it off with `"search": false`. Settings → General → View sets both.

## 0.1.6

### Patch Changes

- aecff0e: Row groups can have a label: `"groups": { "Reviews": { "label": "1 waiting", "tone": "warning" } }` shows it in a pill at the right of the heading, after a line from the name.
- b602b14: An `icon` can be an SF Symbol in the row's tone, `"sf:hammer.fill"`, one that moves, `"sf:gearshape.fill:rotate"`, or a loading spinner, `"spinner"`. Emoji and text work as before. `tjuvkik run` warns about symbols and effects it doesn't know.
- d0de73a: A `"spinner"` in the menu bar turns too, like the one in the tile. It holds still with Reduce Motion on.
- 8529133: The `"spinner"` icon visibly turns: its spokes fade behind the brightest one, like the system's spinner. Before, all spokes looked alike, so it seemed to stand still.
- 6ef4d49: Run Now and ⌘R restart a stream panel, and so does a row's command or action, so a stream tile shows what the command changed at once instead of on its next line. Settings → Board's Run Now works for stream panels too.

## 0.1.5

### Patch Changes

- 04a582b: The full-text popup follows what you used last: moving around with the keyboard hides the one under the mouse, and moving the mouse hides the keyboard's. A mouse that stands still no longer brings up its popup while you use the keyboard.

## 0.1.4

### Patch Changes

- 95d9712: See a row's whole text when it's cut: pick it with the keyboard or hold the mouse over it, and after a moment the full text shows under the row. Works in rows and feed panels.

## 0.1.3

### Patch Changes

- 900e819: Jump between tiles from the keyboard: Tab and ⇧Tab go to the next and previous tile, and ⌥ with an arrow to the next tile that way, wherever you are in its list. You land on the row you were last on in that tile. `"jumpKey"` picks another key than ⌥, or `"none"`, and Settings → General → Glance sets it too. The bar under the tiles shows the keys.

## 0.1.2

### Patch Changes

- 54cecdf: `"dim": true` in config.jsonc darkens the screen behind the glance, or a number from 0 to 1 for how much. Settings → General → Glance sets it too.
- 54cecdf: `"focusOnOpen": "last"` opens the glance on the row you were on when it closed, instead of the most urgent one. Settings → General → Glance sets it too.
- 54cecdf: The bar with the keyboard shortcuts sits right under the lowest tile, not under empty rows of the grid.
- d54de7f: A tile's size is now columns x rows, like `"2x1"`, `"3x1"` for a wide strip or `"1x2"` for a tall one. The old names `s`, `m`, `l` and `xl` still work. Long lists scroll: press ↓ on the last row in view, or use the trackpad or mouse wheel over the tile, and a small "↓ 5" shows what's left below.
