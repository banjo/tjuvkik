# Notifications

A panel can send a macOS notification when something changes, so you don't have to glance to know. Panels only run while the glance is closed if they run in the [background](panels.md#background), so a panel that notifies needs background runs on.

## From a script

A script prints `notify` next to its content, with any [content type](script-output.md):

```json
{
  "rows": [{ "title": "Fix login bug", "tone": "warning" }],
  "notify": [
    { "id": "ses_abc-blocked", "title": "Agent waiting", "body": "Bash: rm -rf node_modules", "command": "agent-watcher focus ses_abc" }
  ]
}
```

| Field | |
|---|---|
| `id` | Required. Names the notification: one is sent per `id`. |
| `title` | Required. |
| `subtitle` | A line under the title. |
| `body` | The text. |
| `url` | Opened when the notification is clicked. |
| `command` | Run when the notification is clicked, in the panel's folder, like a menu row's. Wins over `url`. |

- A notification is sent the first time its `id` shows up in the panel's output, and withdrawn from Notification Center when the `id` is gone. An `id` that stays shows nothing new.
- The first output a panel gives after Tjuvkik starts, or after its config changes, sends nothing: what's already there counts as seen. Only what's new after that is sent.
- Clicking runs its `command` or opens its `url`. With neither, it does nothing.

## A panel's `notify`

In [panel.jsonc](panels.md#settings), or in an entry in [config.jsonc's `panels`](config.md#panels), whose keys win:

```jsonc
"notify": false                                                // this panel never notifies
"notify": { "sound": false, "minInterval": "1m", "on": ["failed", "warning"] }
```

| Key | Default | |
|---|---|---|
| `sound` | the global `sound` | Play the system's notification sound. |
| `minInterval` | none | At most one notification this often, like `"1m"`, at least `1s`. |
| `on` | `[]` | Notifications the script doesn't print. See below. |

### `on`

So `cli` panels and scripts that don't print `notify` can notify too:

- `"failed"`: while the panel shows an error, like a failed run, a stream that exited or a missing tool. The title is `<panel title> failed`, the body the error. It's withdrawn when the error clears.
- `"warning"` and `"error"`: each row with that tone, in rows output only. The title is the row's title, the subtitle the panel's title, the body the row's `note`, else its `subtitle`. Clicking does what the row's `url` or `command` does.

### `minInterval`

What comes in within the interval waits. When it has passed, one waiting notification is sent as is, and several as one: the panel's title, with `3 new: A, B, C`. A waiting one whose `id` disappears is dropped.

## Global settings

In [config.jsonc](config.md#notifications):

```jsonc
"notifications": {
  "enabled": true,
  "sound": true,
  "quietHours": "22:00-07:00",
  "whileOpen": false,
}
```

| Key | Default | |
|---|---|---|
| `enabled` | `true` | `false`: no panel notifies. |
| `sound` | `true` | The system's default sound. |
| `quietHours` | none | Nothing is delivered between these times, local time. It may cross midnight. |
| `whileOpen` | `false` | Deliver while the glance is showing. |

In quiet hours, or while the glance is open, new notifications are dropped, not delayed: they count as seen and aren't sent later. Focus modes apply as for any app.

## Permission

macOS asks the first time Tjuvkik is about to deliver a notification. If you deny it, the menu says "Notifications are off for Tjuvkik" and links to Notification settings.
