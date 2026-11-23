# Tjuvkik docs

Hold fn to glance at your agents, pull requests and anything else you plug in. Let go to close it.

Settings… (⌘,) in the menu bar menu changes the trigger, the view, the board and the theme for you. It edits `config.jsonc` in place, keeping your comments.

1. [Install](install.md): Homebrew, first start, permissions, the 🌐 key.
2. [Config](config.md): `config.jsonc`, theme, trigger, board or [Spotlight](config.md#spotlight), and which panels to show.
3. [Panels](panels.md): `panel.jsonc`, a command that fills a tile.
4. [Script output](script-output.md): the JSON a script panel prints.
5. [Notifications](notifications.md): macOS notifications from panels.
6. [Themes](themes.md): colors, blur and corner radius.
7. [Sync and share](sync.md): dotfiles, export and import.
8. [Command line](cli.md): `tjuvkik validate`, `run`, `preview`, `new` and `schema`.

Everything lives in `~/.config/tjuvkik/`:

```
config.jsonc               theme, trigger and which panels to show
panels/<name>/panel.jsonc  a panel; its command runs in this folder
themes/<name>.jsonc        your own themes
schemas/                   written by Tjuvkik, for editor completion
```
