# Tjuvkik v1 plan

Hold fn to glance at a passive Bento board ("Framed": the Spotlight-sized frame, centered near the top) with the state of your coding agents and anything else you plug in. Let go to close it. Design reference: `design/prototype.html` (the "Framed" view).

## Scope

In v1:

- Hold fn: show the Framed Bento glance. Release: hide it. fn together with another key (fn+arrows, fn+F-keys) cancels.
- Passive: no keyboard capture, no clicks (the panel ignores the mouse).
- Modules: **agents** (native, from agent-watcher), **script** (a command printing rows as JSON), **cli** (a command's plain text output).
- Config in `~/.config/tjuvkik/` (JSON with comments): `config.jsonc`, a folder per panel, a file per theme. Reloaded when saved, syncable with dotfiles, exportable as a zip.
- Themes: Dark glass, Light glass, Dracula, plus custom themes in the config.
- Menu bar icon with the most urgent agent icon and count; menu with Open config, Reload, Launch at login, Quit.
- Launch at login.

Later, not in v1, but the code leaves room for them:

- Spotlight view (`"view": "spotlight"`): double-tap fn, keyboard navigation, jumping. It needs the Accessibility permission to take keys.
- Web modules (HTML in a WKWebView).
- Fullscreen and Edges layouts.
- Clicking a row to act on it (jump to an agent, open a PR).

## Decisions

| Area | Choice | Why |
| --- | --- | --- |
| Language/UI | Swift 6, AppKit shell + SwiftUI views | fn event tap, non-activating panel, material blur and status item are native APIs |
| Build | Swift Package Manager, no Xcode project | Command Line Tools are enough (`swift build`); macOS 15 target |
| Dependencies | None | Foundation's `JSONDecoder.allowsJSON5` reads JSON with comments and trailing commas |
| Repo | Private, `banjo/tjuvkik` | |
| Commits | Conventional Commits, one per coherent change | |
| App type | Agent app (`LSUIElement`), no Dock icon | |
| fn | `CGEvent` tap, listen-only, `flagsChanged` + `keyDown` | Needs only Input Monitoring; listen-only never swallows keys |
| Panel | `NSPanel`, borderless + non-activating, `ignoresMouseEvents`, joins all Spaces and full-screen apps | Never steals focus from the terminal |
| Glass | `NSVisualEffectView` (behind-window blending) per tile | SwiftUI materials don't blur what's behind the window |
| Grid | Custom SwiftUI `Layout`: 4 columns × 3 rows, dense packing | SwiftUI's `Grid` can't span rows |
| Signing | Stable self-signed code signing certificate | Input Monitoring stays granted across rebuilds; no paid Apple account needed |

## Config

Everything lives in one folder, `$XDG_CONFIG_HOME/tjuvkik/` (default `~/.config/tjuvkik/`), so it can be kept in dotfiles and stowed:

```
config.jsonc               theme, fn, and which panels go where, in order, at what size
panels/<name>/panel.jsonc  what a panel is: type, title, command, interval, default size
panels/<name>/*.sh         its scripts; commands run in the panel's folder
themes/<name>.jsonc        custom themes
schemas/                   written by the app, for editor completion through "$schema"
```

```jsonc
// config.jsonc
{
  "$schema": "./schemas/config.schema.json",
  "view": "bento",          // "spotlight" later
  "layout": "framed",       // "fullscreen", "edges" later
  "theme": "dark-glass",    // "light-glass", "dracula", or a file in themes/
  "trigger": { "holdMs": 250 },
  "launchAtLogin": true,
  "panels": [
    { "panel": "agents", "size": "xl" },   // built in, no folder
    { "panel": "github" },                 // the panel's own size
    { "panel": "pods", "size": "m" }       // overrides it
  ]
}

// panels/pods/panel.jsonc
{ "type": "cli", "title": "Pods", "command": "kubectl get pods -n logbook-qa", "every": "30s", "size": "m" }

// themes/mine.jsonc
{ "extends": "dracula", "accent": "#ff79c6" }
```

- Files end in `.jsonc` (editors accept comments in it); `.json` is read too, and `.jsonc` wins if both exist.
- The default files are written on first run; existing files are never overwritten.
- `schema/*.schema.json` are hand-written; `SchemaTests` fail if they drift from the loader's keys and values.
- Sizes on the 4×3 grid: `s` 1×1, `m` 2×1, `l` 2×2, `xl` 2×3. Panels that don't fit are left out with a warning.
- `every`: `30s`, `5m`, `1h`. Minimum 5s.
- Reload: the app compares the files' modification dates once a second, following symlinks, so it works whether stow links the folder or single files.
- Invalid config: keep the last good one and show the errors in the menu (file, path in the JSON, message).
- Values not available in v1 (`"view": "spotlight"`) fall back to the default with a warning, so configs written for later versions still load.
- Export/Import in the menu: a zip of the folder (without `schemas/`, symlinks followed). Import checks the zip's config first, backs up the current one to `~/Library/Application Support/Tjuvkik/Backups/`, and replaces the folder's contents (not the folder, so a stow link survives).

### Script module output

The command prints one JSON object to stdout:

```jsonc
{
  "hero": { "value": "1", "label": "review requested", "tone": "warning" },
  "progress": 0.62,
  "rows": [
    { "icon": "👀", "title": "FE - Logbook: Export bookings", "subtitle": "vgcs/logbook #1284", "trailing": "1h", "tone": "warning", "url": "https://github.com/…" }
  ]
}
```

- Everything is optional except `rows`. `tone` is `normal`, `muted`, `warning`, `error`, `success`, `info` or `accent`, and each theme maps it to a color.
- `url` is ignored in v1, but kept for clicks in Spotlight later.

### Running commands

- Run with `/bin/sh -c`, with `PATH` captured once from your login shell (`$SHELL -lic 'printf %s "$PATH"'`), so Homebrew, `gh` and `kubectl` work without a terminal.
- Default timeout 10s (`timeout` per tile), stdout capped at 256 KB, ANSI escapes stripped for `cli`.
- On failure the tile keeps the last good content, marks it as stale, and shows the stderr tail.
- Refreshed on their interval in the background. When the glance opens, a tile older than its interval refreshes at once.

## Architecture

```
Package.swift
Sources/
  TjuvkikCore/            no AppKit; unit tested
    Config/               Config, Tile, Theme reference, duration parsing, loading + validation, defaults
    Modules/              Module protocol, ModuleContent, ScriptModule, CLIModule, AgentsModule
    Running/              CommandRunner (Process, timeout, PATH, output cap), Scheduler
    Themes/               Theme tokens, built-ins, custom theme resolution
  Tjuvkik/                the app
    App/                  AppDelegate, menu bar item, launch at login (SMAppService)
    Trigger/              FnTrigger (event tap, hold/cancel state machine), permission checks
    Panel/                GlancePanel (NSPanel), placement, show/hide animation
    Views/                BentoView, BentoLayout, TileView, renderers (rows, text, agents), VisualEffect
Tests/TjuvkikCoreTests/
schema/config.schema.json
scripts/bundle.sh          build, assemble Tjuvkik.app, sign, install to ~/Applications
examples/panels/           github/ (gh script panel), example cli panels
design/prototype.html
```

A module produces `ModuleContent`: `.rows(RowsContent)`, `.text(String)`, and later `.web(URL)`. Tiles render content by its type, so a new module type only needs to produce one of these. Spotlight will render the same content as list + preview.

## Phase 0: Setup (done)

1. Create the private repo `banjo/tjuvkik`, push `design/` and this plan.
2. Swift package with the `TjuvkikCore` and `Tjuvkik` targets. Check that `swift test` works with only Command Line Tools installed; if Swift Testing doesn't, use XCTest or install Xcode.
3. `scripts/bundle.sh`: release build, `Tjuvkik.app` with `Info.plist` (`LSUIElement`, bundle ID, version), signed with the "Tjuvkik Dev" certificate, installed to `~/Applications`. README steps to create the certificate once in Keychain Access.
4. An empty agent app with a menu bar item and Quit.

Done when the app builds, installs and starts from `~/Applications` with a menu bar icon.

## Phase 1: fn trigger and panel (done)

1. `FnTrigger`: listen-only event tap on `flagsChanged` and `keyDown`.
   - fn goes down with no other modifiers: start a `holdMs` timer.
   - The timer fires while fn is still down: show.
   - fn goes up: hide.
   - Any key down or other modifier while fn is held: cancel, and hide if shown.
   - The tap is disabled by timeout or user input: re-enable it.
2. Permission: check with `CGPreflightListenEventAccess`, ask with `CGRequestListenEventAccess`. Without it, the menu shows "Allow Input Monitoring…", which opens System Settings.
3. `GlancePanel`: borderless non-activating `NSPanel`, clear background, ignores the mouse, level above normal windows, joins all Spaces and full-screen apps. Placed on the screen of the focused window (the frontmost app's topmost normal window from `CGWindowListCopyWindowInfo`, matched to the `NSScreen` it overlaps most; needs no permission), falling back to the screen with the mouse. Centered, 13% from the top of the visible frame, `min(1080, width − 48)` × `min(580, 66% of height)`.
4. Show: tiles fade and scale in from 0.97, staggered 30ms, 200–260ms ease-out. Hide: 120ms fade. Only a fade when Reduce Motion is on.
5. README: set "Press 🌐 key to" to "Do nothing" in System Settings → Keyboard.

Done when holding fn shows a placeholder panel over any app and Space, letting go hides it, fn+arrow doesn't show it, and the terminal keeps focus.

## Phase 2: Config and themes (done)

1. `Config` with `Codable`, read with `allowsJSON5`. Defaults written on first run.
2. Validation with readable errors (unknown theme, bad size or duration, tiles that don't fit). Keep the last good config.
3. Watch the config directory (editors replace the file) and reload, with a 200ms debounce.
4. Themes: tokens for panel color, blur on/off, well, ink, text levels, line, tones, corner radius. Built-ins: Dark glass, Light glass, Dracula. Custom themes `extends` one and override tokens.
5. JSON Schema and unit tests: JSON5 parsing, durations, validation messages, theme resolution.

Done when changing `theme` or `panels` in the file updates the panel within a second, and a broken edit shows an error in the menu without losing the board.

## Phase 3: Modules and Bento grid (done)

1. `Module` protocol, `ModuleContent`, and a `Scheduler` that refreshes each tile on its interval, and on open when stale.
2. `CommandRunner`: login-shell PATH, timeout, output cap, exit status, stderr tail.
3. `ScriptModule` (decodes the JSON above) and `CLIModule` (text, ANSI stripped, as many lines as fit).
4. Tile placement on the grid (dense packing is done in Phase 2, `BentoPacking`).
5. `TileView`: header (title, kind tag, interval or "live", stale marker), then the content renderer: hero, progress bar, rows (icon, title, subtitle, trailing, tone), or monospace text. Rows that don't fit are cut, not scrolled.
6. Example panel `examples/panels/github/` (`panel.jsonc` + `github.sh` using `gh`: review requests and your open PRs).
7. Tests: script output decoding, runner timeout and output cap, layout packing.

Done when the GitHub script tile and a `kubectl`/`git status` CLI tile render and refresh, and a failing command shows its error.

## Phase 4: Agents (done)

Agents aren't built in: agent-watcher is a script in dotfiles, and there's no shared protocol for agent state, so the app shouldn't know about it. Instead:

1. agent-watcher got `list --json`, every session with state, icon, place, title, `since`, key, ID and what a blocked session waits for, and `--watch`, which prints a new line on each change.
2. Panels got `"mode": "stream"`: the command keeps running, and each line is a new JSON document (script) or output line (cli). Restarted with backoff when it exits.
3. Rows got `group`, `note` (the waiting text under ❓ rows) and a `summary` line of chips.
4. `examples/panels/agents/` streams agent-watcher through `agents.jq`.
5. Panels got metadata (`description`, `author`, `version`) and `requires`, checked on PATH.

Still open: the menu bar icon showing the most urgent agent. Without a built-in agents module, it could show a panel's `summary`, picked in `config.jsonc` (`"menuBar": "agents"`).

## Phase 5: Polish and ship

1. Launch at login with `SMAppService.mainApp`, toggled from the menu and `launchAtLogin`.
2. Menu: summary line, Open config (default editor), Reload config, config errors, Launch at login, Quit.
3. Multiple displays, Spaces, full-screen apps, light/dark wallpaper, Reduce Motion and Reduce Transparency (solid panel).
4. README: install, certificate, permissions, config reference, writing a script module.
5. Use it daily for a week; collect issues for v1.1 (likely Spotlight).

## Later: sharing panels

A panel is a self-contained folder, so sharing one is copying a folder. Steps, when it's worth it:

1. "Add Panel from URL…" in the menu, or `tjuvkik add github:<owner>/<repo>/<path>`, which downloads a panel folder.
2. A registry: a repo with an `index.json` of panels (name, description, author, requires, path), browsable from the menu.

The metadata in `panel.jsonc` (description, author, version, requires) is there for this.

## Settled

- Bundle ID: `se.banjo.tjuvkik`.
- App icon: later. v1 uses an SF Symbol in the menu bar.
- Jira: no tile in v1; a script module can be written later.
- Work Mac (MDM): check that Input Monitoring can be granted to a self-signed app at the start of Phase 1.
- Display: the glance opens on the screen of the focused window.
- macOS reference: the `macos-patterns` skill (installed in dotfiles) for panels, window levels, screen geometry and launch at login.
