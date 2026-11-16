# Panels

A panel is a folder in `panels/` with a `panel.jsonc`. Add it to `panels` in [config.jsonc](config.md) to show it.

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
  "size": "s",
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
| `size` | `"s"` | `s`, `m`, `l` or `xl`. `config.jsonc` can override it. |
| `history` | | For a [chart](types/chart.md) whose script prints only its value: how many values to keep as the series, 2 to 1000. |
| `file` | | A [markdown](types/markdown.md) panel only: a file to show instead of a command's output, reloaded when it changes. `~`, absolute, or in the panel's folder. |
| `requires` | `[]` | Commands that must be on PATH. If one is missing, the tile says so instead of running. |
| `description`, `author`, `version` | | For sharing. Not shown. |

Durations take `ms`, `s`, `m` or `h`: `"500ms"`, `"30s"`, `"5m"`, `"1h"`.

## Types

- **`cli`** shows the output as is, colors removed, as many lines as fit.
- **`script`** prints JSON that the tile shows as rows, or as the type its top-level key names. See [Script output](script-output.md).
- **A content type**, like `stats`, is a script panel whose output is always read as that type.

## Modes

- **`interval`** runs the command every `every`.
- **`stream`** keeps the command running. A script prints one JSON document per line, each time something changes, and the tile updates at once. A cli panel shows the latest lines, like `tail -f`. `every` and `timeout` don't apply.

## When a command fails

A run fails if it exits with a non-zero status, times out, or a script prints invalid JSON. The tile keeps what it last showed, marks it stale and shows the last lines of stderr.

A stream that exits is restarted after 1 second, then after up to 30 seconds if it keeps exiting.

## Environment

Commands get your login shell's PATH, so tools from Homebrew, mise and the like are found. `TJUVKIK_PANEL` is the panel's name.

## Examples

A cli panel:

```jsonc
{ "type": "cli", "title": "Pods", "command": "kubectl get pods", "every": "30s", "size": "m" }
```

A log that updates live:

```jsonc
{ "type": "cli", "mode": "stream", "title": "Server", "command": "tail -f /tmp/server.log", "size": "l" }
```

More in [examples/panels](../examples/panels):

- [`agents`](../examples/panels/agents): coding agents from [agent-watcher](https://github.com/banjo/dotfiles/tree/master/.config/agent-watcher), streamed.
- [`github`](../examples/panels/github): pull requests waiting for your review, then yours.
