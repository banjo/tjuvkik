# Tjuvkik

Hold fn to glance at your coding agents and anything else you plug in. Let go to close it.

## Quick start

```sh
brew install --cask banjo/tap/tjuvkik
```

A short setup picks your trigger, [starter panels](starters/panels) and theme. Turn on Input Monitoring when asked, then hold fn. Config lives in `~/.config/tjuvkik/`.

## Docs

- [Install](docs/install.md)
- [Config](docs/config.md)
- [Panels](docs/panels.md)
- [Script output](docs/script-output.md)
- [Themes](docs/themes.md)
- [Sync and share](docs/sync.md)
- [Command line](docs/cli.md)

## Development

```sh
scripts/create-cert.sh   # once
scripts/bundle.sh --open # build, install and start
swift test
```

See [internal/building.md](internal/building.md).
