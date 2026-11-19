# Panels

A panel is a folder in `panels/` with a `panel.jsonc`. Add it to `panels` in [config.jsonc](config.md) to show it.

A panel placed on the board is a tile. One panel can be placed many times, each tile with its own `id`, title and [options](#options).

Right-click a tile in the glance to run it now, open its `panel.jsonc`, show its folder in Finder, or open Settings.

`panels/<name>/panel.jsonc`, with every setting:

```jsonc
{
  "$schema": "../../schemas/panel.schema.json",
  "description": "Pull requests waiting for your review",
  "author": "banjo",
  "version": "1.0.0",
  "requires": ["gh", "jq"],
  "type": "script",
  "mode": "interval",
  "title": "GitHub",
  "command": "./github.sh",
  "every": "60s",
  "timeout": "10s",
  "background": true,
  "size": "1x1",
}
```

## Settings

| Key | Default | |
|---|---|---|
| `type` | required | `cli`, `script`, or a [content type](script-output.md) like `chart` or `table`. |
| `command` | required, unless `file` | Runs with `/bin/sh -c` in the panel's folder. |
| `mode` | `"interval"` | `interval` or `stream`. |
| `title` | folder name | Shown on the tile. |
| `every` | `"60s"` | How often an interval panel runs. At least `5s`. |
| `timeout` | `"10s"` | How long an interval run may take. |
| `size` | `"1x1"` | Columns x rows, like `"2x1"`, or `"3x1"` for a wide strip. See [sizes](config.md#panels). `config.jsonc` can override it. |
| `history` | | For a [chart](types/chart.md) whose script prints only its value: how many values to keep as the series, 2 to 1000. |
| `file` | | A [markdown](types/markdown.md) panel only: a file to show instead of a command's output, reloaded when it changes. `~`, absolute, or in the panel's folder. |
| `requires` | `[]` | Commands that must be on PATH. If one is missing, the tile says so instead of running. |
| `background` | `true` | How often an interval panel runs while the glance is closed: `true`, `false` or a duration like `"5m"`, at least `5s`. See [Background](#background). |
| `notify` | `true` | `false`, or when and how the panel notifies. See [Notifications](notifications.md#a-panels-notify). |
| `options` | | Settings each tile sets in `config.jsonc`. See [Options](#options). |
| `description`, `author`, `version` | | For sharing. Not shown. |

Durations take `ms`, `s`, `m` or `h`: `"500ms"`, `"30s"`, `"5m"`, `"1h"`.

## Options

A panel can take options, so the same panel works for several repos, clusters or hosts without editing its script. The panel declares them in `options`; each tile sets their values in [config.jsonc](config.md#panels).

| Key | |
|---|---|
| `type` | Required: `string`, `number` or `boolean`. |
| `title` | A label for forms. Default: the option's name. |
| `description` | What it's for. |
| `default` | The value when a tile doesn't set it. |
| `required` | `true`: every tile of the panel must set it. |
| `enum` | The allowed values of a `string` option. |

```jsonc
// panels/ci/panel.jsonc: what the panel takes
"options": {
  "repo":   { "type": "string", "title": "Repository", "description": "owner/name", "required": true },
  "limit":  { "type": "number", "default": 10 },
  "branch": { "type": "string", "enum": ["main", "release"], "default": "main" },
  "drafts": { "type": "boolean", "default": false }
}
```

```jsonc
// config.jsonc: what you set
"panels": [
  { "panel": "ci", "id": "ci-app",  "title": "CI · app",  "options": { "repo": "banjo/tjuvkik" } },
  { "panel": "ci", "id": "ci-dots", "title": "CI · dots", "options": { "repo": "banjo/dotfiles", "limit": 5 } },
]
```

The command reads them from the environment, in two ways:

- One variable per option, `TJUVKIK_OPTION_<NAME>`: the name upper-cased, `-` turned into `_`. Numbers print without `.0` when whole (`10`, `2.5`), booleans as `true` or `false`.
- All of them as one JSON object, with sorted keys, in `TJUVKIK_OPTIONS`.

```sh
gh run list --repo "$TJUVKIK_OPTION_REPO" --limit "$TJUVKIK_OPTION_LIMIT"
repo=$(echo "$TJUVKIK_OPTIONS" | jq -r .repo)
```

An option with no value and no default is left out of both. Options are never put into `command`, since `sh -c` would run them.

Option names start with a letter, then use letters, digits, `-` and `_`. A tile that sets an option the panel doesn't declare, or leaves out a required one, is an error.

### Secrets

Don't put tokens in options: `config.jsonc` often ends up in a dotfiles repo. Read them in the script instead, with `gh auth token`, `security find-generic-password -s <name> -w`, or an environment variable. See [#23](https://github.com/banjo/tjuvkik/issues/23).

## Types

- **`cli`** shows the output as is, colors removed, as many lines as fit.
- **`script`** prints JSON that the tile shows as rows, or as the type its top-level key names. See [Script output](script-output.md).
- **A content type**, like `stats`, is a script panel whose output is always read as that type.

## Modes

- **`interval`** runs the command every `every`.
- **`stream`** keeps the command running. A script prints one JSON document per line, each time something changes, and the tile updates at once. A cli panel shows the latest lines, like `tail -f`. `every` and `timeout` don't apply.

## Background

While the glance is closed, an interval panel runs on its `background`:

- `true`, the default: as often as it does while you glance, every `every`.
- `false`: only while you glance. Opening the glance runs it at once if it's older than `every`.
- A duration like `"5m"`: that often, at least `5s`.

Cheap panels, like agents, can keep their interval. One that calls `gh` or `kubectl` is worth `"5m"`, or `false` if you only care when you look.

Background runs pause while the screen is locked or the displays sleep, and while Low Power Mode is on, unless [`pause`](config.md#pause) turns that off. The glance always runs panels on their `every`.

Stream panels and markdown panels that read a `file` are unaffected: a stream keeps running, and a file is read when it changes.

A panel can also run without a spot on the grid, for the menu bar: see [`show`](config.md#panels).

## When a command fails

A run fails if it exits with a non-zero status, times out, or a script prints invalid JSON. The tile keeps what it last showed, marks it stale and shows the last lines of stderr.

A stream that exits is restarted after 1 second, then after up to 30 seconds if it keeps exiting.

`tjuvkik run <tile|panel>` runs a panel once from a terminal, the same way, and prints the error. See [Command line](cli.md).

## Environment

Commands get your login shell's PATH, so tools from Homebrew, mise and the like are found. `TJUVKIK_PANEL` is the panel's folder name, `TJUVKIK_ID` the tile's id, and each [option](#options) is a `TJUVKIK_OPTION_<NAME>`, all of them as JSON in `TJUVKIK_OPTIONS`. `TJUVKIK_RUN` says what started the run: `glance` or `background` for an interval panel, `stream`, `action` for a row's command, or `cli`.

## Examples

A cli panel:

```jsonc
{ "type": "cli", "title": "Pods", "command": "kubectl get pods", "every": "30s", "size": "2x1" }
```

A log that updates live:

```jsonc
{ "type": "cli", "mode": "stream", "title": "Server", "command": "tail -f /tmp/server.log", "size": "2x2" }
```

More in the [starter panels](#starter-panels).

## Starter panels

Tjuvkik ships a few panels to start from, in [starters/panels](../starters/panels). Picking one during setup copies its folder into `panels/`, unless a folder with that name is already there, and adds a tile. It's then yours to change.

| Folder | Shows | Needs |
|---|---|---|
| `disk` | disk use (already in the default config) | nothing |
| [`cpu-memory`](../starters/panels/cpu-memory) | CPU, memory and load, as `stats` | nothing |
| [`battery`](../starters/panels/battery) | battery charge, as `meters` | a Mac with a battery |
| [`github`](../starters/panels/github) | PRs waiting for your review, then yours | `gh`, `jq` |
| [`demo-agents`](../starters/panels/demo-agents) | **sample** coding agents, as rows | nothing |
| [`demo-slack`](../starters/panels/demo-slack) | **sample** Slack mentions, as a `feed` | nothing |

The demos show sample data, to show what a panel can look like.
