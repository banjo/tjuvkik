# Script output

A `script` panel prints JSON to stdout. By default the tile shows it as rows. A top-level key picks another type, drawn its own way at each size:

- [`chart`](types/chart.md): one number and where it's heading.
- [`meters`](types/meters.md): how full, how far, how close to a limit.
- [`grid`](types/grid.md): many things at once, a colored cell each, or a heatmap.
- [`timeline`](types/timeline.md): what's now, what's next, and how long until.
- [`stats`](types/stats.md): a few numbers, each against its last period.
- [`markdown`](types/markdown.md): notes, runbooks and answers in Markdown, or a file the panel reads.
- [`keyvalue`](types/keyvalue.md): exact facts, grouped, with values cut in the middle.
- [`table`](types/table.md): the same fields for every row, in columns.
- [`feed`](types/feed.md): who said what, and when, newest first, with unread marked.
- [`checklist`](types/checklist.md): steps, and what's done, next and stuck.

`summary`, `menuBar` and [`notify`](notifications.md) work with every type. Setting `"type"` in [panel.jsonc](panels.md#types) to a type's name, like `"stats"`, makes the panel always read its output as that type.

## Rows

Every field:

```json
{
  "hero": { "value": "2", "label": "reviews requested", "tone": "warning" },
  "summary": [
    { "icon": "❓", "value": "2", "label": "waiting", "tone": "warning" }
  ],
  "progress": 0.62,
  "rows": [
    {
      "icon": "👀",
      "title": "Export bookings",
      "subtitle": "logbook #1284",
      "trailing": "1h",
      "tone": "warning",
      "group": "Reviews",
      "note": "Waiting for approval",
      "url": "https://github.com/acme/app/pull/1284"
    }
  ],
  "menuBar": {
    "icon": "👀",
    "text": "2",
    "tone": "warning",
    "menu": [
      { "icon": "👀", "title": "Export bookings", "subtitle": "logbook #1284", "trailing": "1h", "url": "https://github.com/acme/app/pull/1284" }
    ]
  }
}
```

The smallest valid output:

```json
{ "rows": [{ "title": "All good" }] }
```

Only `rows`, each row's `title` and the hero's `value` are required. A `stream` panel prints one such document per line.

## Fields

| Field | |
|---|---|
| `hero` | A big number at the top: `value` (required), `label`, `tone`. |
| `summary` | A line of small counts. Each has `icon`, `value`, `label` and `tone`, all optional. |
| `progress` | A bar, from 0 to 1. |
| `rows` | As many as fit, in order. |
| `menuBar` | What the panel shows in the menu bar. See [Menu bar](#menu-bar). |
| `notify` | macOS notifications, one per `id`. See [Notifications](notifications.md). |

Each row:

| Field | |
|---|---|
| `title` | Required. |
| `icon` | An emoji or a short text. |
| `subtitle` | A second, fainter line. |
| `trailing` | On the right, like a time or count. |
| `tone` | Colors the row. |
| `group` | A heading over each run of rows with the same group. |
| `note` | A line under the row in its tone, for what needs you. |
| `url` | Opened when the row is clicked in the glance or picked in the menu. Closes the glance. |
| `command` | Run when the row is clicked in the glance or picked in the menu, in the panel's folder. Wins over `url`. Keeps the glance open and runs the panel again, so the tile shows the result. |

## Menu bar

Shown when the panel is in `menuBar` in [config.jsonc](config.md#menu-bar).

| Field | |
|---|---|
| `icon`, `text` | Shown in the menu bar: `👀 2`. |
| `tone` | Colors it. |
| `menu` | Rows in the menu, under the panel's title. Same fields as `rows`; `subtitle` and `note` go on a second line. |

- Leave `menuBar` out to show the first `summary` chip, with the whole summary in the menu.
- Set `"menuBar": null` to show nothing, like when nothing needs you.

A row's `command` runs like the panel's, with your login shell's PATH. What it starts in the background keeps running, so it can open apps or focus windows. If it fails, the error shows on the tile.

## Tones

`normal`, `muted`, `warning`, `error`, `success`, `info` and `accent`. The theme decides the colors.

## Example

A script that lists files in Downloads:

```sh
#!/bin/sh
ls -t ~/Downloads | head -20 | jq -R '{ title: . }' | jq -s '{ rows: . }'
```
