# Sync and share

## Dotfiles

Keep `~/.config/tjuvkik/` in your dotfiles and link it, with stow or by hand:

```sh
ln -s ~/dotfiles/.config/tjuvkik ~/.config/tjuvkik
```

Tjuvkik follows links and reloads when linked files change. Ignore `schemas/`, which Tjuvkik writes itself:

```gitignore
.config/tjuvkik/schemas/
```

Check the folder before committing, or in CI on a Mac:

```sh
tjuvkik validate --config ~/dotfiles/.config/tjuvkik
```

It exits 1 on errors. See [Command line](cli.md).

## Export and import

From the menu bar menu:

- **Export Config…** saves the folder as a zip.
- **Import Config…** checks the zip, backs up your current config to `~/Library/Application Support/Tjuvkik/Backups/`, then replaces it. A linked folder stays linked.

## Share a panel

A panel is a folder, so copy it into someone's `panels/` and add it to their `config.jsonc`. Fill in `description`, `author`, `version` and `requires` in `panel.jsonc`, so others know what it does and what it needs.
