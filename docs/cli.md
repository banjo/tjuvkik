# Command line

`scripts/bundle.sh` links `tjuvkik` into `~/.local/bin`. It's the app's own binary: with a command it runs the command and exits, without one it starts the app.

```sh
tjuvkik new prs --type table   # make panels/prs/ from a template
tjuvkik run prs                # run it once and see what the tile shows
tjuvkik preview prs            # render the tile to prs-m.png
tjuvkik validate               # check the whole config folder
```

Every command reads `~/.config/tjuvkik/` (or `$XDG_CONFIG_HOME/tjuvkik/`). `--config <folder>` reads another one.

## validate

Checks `config.jsonc`, the themes it uses and every panel in `panels/`, including panels that aren't on the board yet. Prints each error and warning with its file and key, then a summary:

```
error: panels/prs/panel.jsonc: every: must be at least 5s, got "1s"
✗ 1 error in config.jsonc and 4 panels
```

Exits 1 on errors, so it works in CI for a dotfiles repo. Warnings don't fail it.

## run

```sh
tjuvkik run <panel> [--raw]
```

Runs the panel as the app does: in its folder, with your login shell's `PATH`, `TJUVKIK_PANEL` set and its `timeout`. Then it says what the tile shows, or why it shows an error:

```
prs: table, ran in 0.84s
  shows table, 4 columns and 8 rows
```

`--raw` prints the command's output as is. A stream panel keeps running and describes each line until Ctrl-C. Exits 1 when the command fails or its output can't be read.

## preview

```sh
tjuvkik preview <panel> [--size s|m|l|xl] [--theme <name>] [-o <file>] [--scale <1-4>]
```

Runs the panel and renders its tile to a PNG, at its size on the largest board, with a transparent background. The size defaults to the one `config.jsonc` gives the panel, else the panel's own; the theme to the one in `config.jsonc`. The file defaults to `<panel>-<size>.png` in the current folder. Blur isn't rendered, so the tile's background is drawn solid.

A failed run renders the tile with its error, and exits 1.

## new

```sh
tjuvkik new <name> [--type <type> | --script | --cli]
```

Makes `panels/<name>/` with a `panel.jsonc` and a `<name>.sh` that prints an example of the type. The type is `script` (rows, the default), `cli`, or a [content type](types/) like `stats` or `table`. Add the panel to `config.jsonc`'s `panels` to show it.

## schema

```sh
tjuvkik schema                 # list the schemas and where they are
tjuvkik schema panel           # print one: config, panel or theme
```
