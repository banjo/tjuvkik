# Tjuvkik docs

Hold fn to glance at your agents, pull requests and anything else you plug in. Let go to close it.

1. [Install](install.md): build, permissions, the 🌐 key.
2. [Config](config.md): `config.jsonc`, theme, fn and which panels to show.
3. [Panels](panels.md): `panel.jsonc`, a command that fills a tile.
4. [Script output](script-output.md): the JSON a script panel prints.
5. [Themes](themes.md): colors, blur and corner radius.
6. [Sync and share](sync.md): dotfiles, export and import.
7. [Command line](cli.md): `tjuvkik validate`, `run`, `preview`, `new` and `schema`.

Everything lives in `~/.config/tjuvkik/`:

```
config.jsonc               theme, fn and which panels to show
panels/<name>/panel.jsonc  a panel; its command runs in this folder
themes/<name>.jsonc        your own themes
schemas/                   written by Tjuvkik, for editor completion
```
