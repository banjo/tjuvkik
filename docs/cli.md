# Command line

Homebrew puts `tjuvkik` on your PATH. It's the app's own binary: with a command it runs the command and exits, without one it starts the app.

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
tjuvkik run <tile|panel> [--raw] [--option key=value]...
```

Takes a tile's id from `config.jsonc` or a panel's folder name. A tile on the board runs with its [options](panels.md#options); anything else is a panel with its option defaults. `--option key=value` sets an option and wins over both; repeat it for more.

```sh
tjuvkik run ci-app                               # the tile's options
tjuvkik run ci --option repo=banjo/tjuvkik       # the folder, with an option
```

Runs the panel as the app does: in its folder, with your login shell's `PATH`, with `TJUVKIK_PANEL`, `TJUVKIK_ID`, the option variables and `TJUVKIK_RUN=cli` set and its `timeout`. Then it says what the tile shows, or why it shows an error:

```
prs: table, ran in 0.84s
  shows table, 4 columns and 8 rows
```

`--raw` prints the command's output as is. A stream panel keeps running and describes each line until Ctrl-C. Exits 1 when the command fails or its output can't be read.

## preview

```sh
tjuvkik preview <tile|panel> [--size s|m|l|xl] [--theme <name>] [-o <file>] [--scale <1-4>] [--zoom <0.75-2>] [--option key=value]...
```

```sh
tjuvkik preview ci-dots --option limit=3
```

Runs the panel and renders its tile to a PNG, at its size at zoom 1, with a transparent background. `--zoom` draws it as the glance does at another [zoom](config.md#grid-and-zoom). Like `run`, it takes a tile's id or a panel's name, and `--option`. The size defaults to the one `config.jsonc` gives the tile, else the panel's own; the theme to the one in `config.jsonc`, for the current appearance when it names one for light and one for dark. The file defaults to `<panel>-<size>.png` in the current folder. Blur isn't rendered, so the tile's background is drawn solid.

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
