# Checklist

Steps, and what's done, next and stuck. The tile is read-only: your script owns the list, whether it comes from todo.txt, Things, Reminders or a GitHub task list.

```json
{
  "items": [
    { "section": "Before" },
    { "title": "Freeze main", "state": "done" },
    { "title": "Smoke test on QA", "state": "doing", "who": "Sara", "note": "export and calendar left" },
    { "title": "PO sign-off", "state": "blocked", "note": "Waiting for Kristian" },
    { "section": "Release" },
    { "title": "Deploy to prod", "who": "Anton" }
  ],
  "caption": "steps · release Thu 14:00",
  "foldDone": true
}
```

| Size | Shows |
|---|---|
| `s` | The count, a bar, and the next step: the first one in progress, else the first one to do. |
| `m` | The steps, in two columns when one doesn't fit. Sections are left out. |
| `l`, `xl` | The count and bar, then sections, steps and notes. With `foldDone`, done steps are hidden behind a `✓ 3 done` line. |

Steps that don't fit are cut, never scrolled.

## Fields

| Field | |
|---|---|
| `items` | Required. Steps and sections, in order. A single step works without an array. |
| `caption` | Next to the count, like `steps · release Thu 14:00`. |
| `foldDone` | `true` hides done and skipped steps in an `l` tile. Off by default. |

Each step:

| Field | |
|---|---|
| `title` | Required. Text or a number. |
| `state` | `todo` (the default), `doing`, `done`, `blocked` or `skipped`. `true` and `false` mean done and todo. Unknown states read as `todo`. |
| `who` | Who's on it, at the end of the line. |
| `note` | A line under the title. Red when the step is blocked. |

A section is `{ "section": "Before" }`: a heading over the steps after it. With `foldDone`, a section whose steps are all done is hidden too.

The count is done steps out of all steps. Skipped steps count as neither. The bar shows done steps in the success color, then steps in progress in the accent color.

`summary` and `menuBar` work as for [rows](../script-output.md#menu-bar): they set what the menu bar shows.

## Example

The task list in a GitHub pull request's description, with [gh](https://cli.github.com) and [jq](https://jqlang.org):

```sh
#!/bin/sh
gh pr view 1284 --repo acme/app --json body --jq .body | jq -R -s '{
  items: [gsub("\r"; "") | split("\n")[] | capture("^\\s*[-*] \\[(?<x>[ xX])\\] (?<title>.*)") |
    { title, state: (if .x == " " then "todo" else "done" end) }],
  caption: "PR #1284"
}'
```

With `"type": "checklist"` in [panel.jsonc](../panels.md), the tile always reads the output as a checklist, and says what's missing when the script prints something else.
