# Tjuvkik

Hold fn to glance at your coding agents and anything else you plug in. Let go to close it.

## Quick start

```sh
scripts/create-cert.sh   # once
scripts/bundle.sh --open # build, install and start
```

Turn on Input Monitoring when asked, then hold fn. Config lives in `~/.config/tjuvkik/`.

## Docs

- [Install](docs/install.md)
- [Config](docs/config.md)
- [Panels](docs/panels.md)
- [Script output](docs/script-output.md)
- [Themes](docs/themes.md)
- [Sync and share](docs/sync.md)

## Development

```sh
swift build
swift test
```

The app icon is drawn in `Resources/AppIcon.svg`. After changing it, run `scripts/make-icon.sh` (needs `brew install librsvg`) to write `Resources/AppIcon.icns`.

See [PLAN.md](PLAN.md) for the v1 plan and [design/prototype.html](design/prototype.html) for the design.
