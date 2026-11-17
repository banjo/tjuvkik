# Table

The same fields for every row, in columns.

```json
{
  "columns": [
    { "title": "Pod", "mono": true, "width": "38%" },
    { "title": "Status", "priority": 1 },
    { "title": "Restarts", "align": "right" },
    { "title": "Age", "align": "right" }
  ],
  "rows": [
    { "cells": ["api-7d9f4-x2kq", { "text": "Running", "tone": "success", "dot": true }, 0, { "text": "2d", "dim": true }] },
    { "cells": ["export-1794-lq", { "text": "CrashLoop", "tone": "error", "dot": true }, { "text": "12", "tone": "error" }, { "text": "41m", "dim": true }], "highlight": true }
  ]
}
```

| Size | Shows |
|---|---|
| `s` | Up to two columns. |
| `m` | Up to four columns. |
| `l`, `xl` | Every column that fits. |

Columns that don't fit the tile's width are dropped from the right. A column with a higher `priority` stays longer: with room for two of the four columns above, you see Pod and Status; give Age `"priority": 2` and you see Status and Age. Rows that don't fit are cut from the bottom.

## Fields

`columns` is required; `rows` can be empty. Each column:

| Field | |
|---|---|
| `title` | The header. A column can also be just its title: `"columns": ["Port", "Process"]`. |
| `mono` | `true` for a monospaced column: IDs, versions, ports. |
| `align` | `left` (default), `right` or `center`. Right-align numbers. |
| `priority` | A number. Higher keeps the column longer when the tile is narrow. Defaults to 0. |
| `width` | The column's share of the table's width, like `"38%"`. Columns without one share what's left. |

Each row:

| Field | |
|---|---|
| `cells` | Required. One per column, in column order. A row can also be just its cells: `["5173", "vite"]`. |
| `highlight` | `true` tints the row in the error tone, or give a tone: `"warning"`. |
| `url` | Opened when the row is clicked in the glance. Closes the glance. |
| `command` | Run when the row is clicked in the glance, in the panel's folder. Wins over `url`. Keeps the glance open and runs the panel again, so the tile shows the result. |

Each cell is text, a number, or an object:

| Field | |
|---|---|
| `text` | What the cell shows. |
| `tone` | The text's color: `success`, `warning`, `error`, `info`, `accent` or `muted`. |
| `dot` | `true` puts a dot in the tone before the text, for a status. |
| `dim` | `true` shows the text in the secondary color, for what matters less. |

Missing cells show empty; extra cells are ignored.

`summary` and `menuBar` work as for [rows](../script-output.md#menu-bar): they set what the menu bar shows.

## Example

Pods in a namespace, with [kubectl](https://kubernetes.io/docs/reference/kubectl/) and [jq](https://jqlang.org). Pods that aren't running are highlighted.

```sh
#!/bin/sh
kubectl get pods -n logbook -o json | jq '{
  columns: [
    { title: "Pod", mono: true, width: "45%" },
    { title: "Status", priority: 1 },
    { title: "Restarts", align: "right" }
  ],
  rows: [.items[] | ((.status.containerStatuses[0].state // {}) | keys[0]) as $state | {
    cells: [
      .metadata.name,
      { text: (.status.containerStatuses[0].state.waiting.reason // .status.phase),
        tone: (if $state == "running" then "success" elif $state == "waiting" then "error" else "muted" end),
        dot: true },
      (.status.containerStatuses[0].restartCount // 0)
    ],
    highlight: ($state == "waiting"),
    command: "kubectl logs -n logbook \(.metadata.name) | open -f"
  }]
}'
```

With `"type": "table"` in [panel.jsonc](../panels.md), the tile always reads the output as a table, and says what's missing when the script prints something else.
