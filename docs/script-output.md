# Script output

A `script` panel prints JSON to stdout. Every field:

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
      "note": "Waiting for approval"
    }
  ]
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

## Tones

`normal`, `muted`, `warning`, `error`, `success`, `info` and `accent`. The theme decides the colors.

## Example

A script that lists files in Downloads:

```sh
#!/bin/sh
ls -t ~/Downloads | head -20 | jq -R '{ title: . }' | jq -s '{ rows: . }'
```
