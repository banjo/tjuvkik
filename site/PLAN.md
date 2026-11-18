# Landing page plan

One page at `tjuvkik.banjoanton.com` that shows the glance and makes developers want to try it. Docs come later.

## Settled

| Area      | Choice                                                                                                                                                          |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Audience  | Developers and coders, many working with AI agents                                                                                                              |
| Message   | The gesture first (hold fn, let go), then "anything you can script is a panel", including the row's actions                                                     |
| Agents    | An example of what a script can show, not a built-in feature. Say "pipe your agent watcher in", never "supports Claude Code"                                    |
| Language  | English                                                                                                                                                         |
| CTA       | "View on GitHub" (`github.com/banjo/tjuvkik`, public, MIT). Under it: "Free and open source · macOS 15+" and "Homebrew coming soon"                             |
| Later CTA | `brew install --cask tjuvkik` with a copy button, replacing "Homebrew coming soon"                                                                              |
| Stack     | Astro, static build, plain CSS with scoped styles, no UI framework, JS only for the hero                                                                        |
| Tooling   | pnpm and Vite+ (`vp`): `vite` overridden to Vite+ core, `vp check` for format, lint and types                                                                   |
| Folder    | `site/` in this repo                                                                                                                                            |
| Hosting   | Cloudflare Pages, domain `tjuvkik.banjoanton.com`                                                                                                               |
| Scope     | One page now; docs from `docs/*.md` through content collections later                                                                                           |
| Look      | Dark only. Same colors as the app and `design/prototype.html`: the desktop gradient (purple, blue, pink), Dracula tones, dark glass tiles. App icon as the logo |
| Fonts     | System font for text, `ui-monospace`/SF Mono/JetBrains Mono for code. No web fonts                                                                              |
| Analytics | Cloudflare Web Analytics, no cookies, no banner                                                                                                                 |

## Copy

- `<title>`: Tjuvkik: a glanceable, scriptable dashboard for macOS
- Headline: **Hold fn. See everything.**
- Subhead: A glanceable dashboard for your Mac. Anything you can script becomes a panel, and it disappears when you let go.
- Footer, "Why the name?": _tjuvkik_ is Swedish for a sneak peek.
- Footer: © Anton Ödman.

## Sections

1. **Hero**: logo, headline, subhead, CTA, and the live glance on a macOS desktop (menu bar, terminal behind it).
2. **How it works**: Hold, Glance, Let go. It never takes focus from your terminal, works over every Space and full-screen app.
3. **Anything you can script**: a `panel.jsonc` and a short shell script next to the tile it makes. Then **act on it**: click a row or press ⌘K for its actions (approve a PR, check out a branch, jump to a session), defined in the same JSON.
4. **Every panel type**: a gallery of all of them, each a real tile with one line on what it's for:
   rows, cli, stats, chart, meters, table, timeline, feed, grid, keyvalue, checklist, markdown.
   Interval or stream (`tail -f`) noted on the tiles.
5. **Built for working with agents**: an agents panel (blocked, failed, working, done) and a notification when one needs you. Honest: you bring the script.
6. **Let your agent build it**: `tjuvkik new → run → preview → validate`. `preview` renders the tile to a PNG, so an agent can see what it made and fix it. JSON Schema for every file, `llms.txt`, and a prompt to copy.
7. **Config as code**: one folder, keep it in dotfiles, reloads on save, `tjuvkik validate` in CI, export and import.
8. **Native and light**: a row of badges. Swift, no dependencies, no Dock icon, pauses when locked or on Low Power.
9. **CTA again and footer**: GitHub, "Why the name?", copyright.

## Hero demo

- The glance is HTML and CSS, rebuilt from `design/prototype.html` (Framed bento, 4×3 grid, dark glass).
- Tiles, each tagged like in the app (`script · 60s`, `cli · stream`):
  - **Agents** (`xl`): the `starters/panels/demo-agents` data
  - **Pull requests** (`m`): review requested
  - **CI** (`s`): stats, passing and failing
  - **CPU and memory** (`s`): meters
  - **Deploys** (`m`): timeline
  - **Pods** (`m`): raw `kubectl get pods` output
- Open it: **hold Space** while the hero is on screen (Space only stops scrolling there), or press and hold the on-screen **fn key** with mouse or finger. Let go to close.
- It opens once by itself about 1.5 s after load, so someone who doesn't try still sees it, then closes when they first press.
- Show: tiles fade and scale in from 0.97, 30 ms stagger. Hide: 120 ms fade. Reduce Motion: fade only.
- On narrow screens the board scales down as one unit; below that it stacks.

## Agent-friendly site

- `/llms.txt`: what Tjuvkik is, install, and links to the docs as raw markdown.
- `/llms-full.txt`: the `docs/` markdown in one file, built from the repo so it never drifts.
- `/schema/config.schema.json`, `/schema/panel.schema.json`, `/schema/theme.schema.json`: copied from `schema/` at build, at stable URLs a `$schema` can point to.
- A copy-paste prompt in section 6, like: "Make a Tjuvkik panel that shows … Use `tjuvkik new`, check it with `tjuvkik run` and `tjuvkik preview`."

## SEO

- One `h1`, a heading per section, real text in the HTML (the hero is HTML, not an image).
- Meta description, canonical `https://tjuvkik.banjoanton.com/`, Open Graph and Twitter card.
- OG image: a 1200×630 PNG of the hero with the glance open, captured with browser-harness and committed to `site/public/og.png`.
- `schema.org` `SoftwareApplication`: name, `operatingSystem: macOS 15`, `applicationCategory: DeveloperApplication`, `offers` price 0, link to GitHub.
- `@astrojs/sitemap`, `robots.txt`, favicon and apple-touch-icon from `Resources/AppIcon.svg`.
- Target phrases in the copy: macOS dashboard, glanceable dashboard, scriptable widgets, menu bar dashboard, dotfiles, AI coding agents, CLI.
- Lighthouse 100 for performance, accessibility, SEO and best practices.

## Structure

```
site/
  PLAN.md
  astro.config.mjs        site URL, sitemap (without /og)
  vite.config.ts          Vite+ lint and format
  public/                 og.png, icons, robots.txt
  src/
    layouts/Base.astro    head, meta, Open Graph, JSON-LD
    pages/index.astro     the page, one component per section
    pages/og.astro        the Open Graph image, 1200×630, noindex
    pages/llms.txt.ts     built from docs/
    pages/llms-full.txt.ts
    pages/schema/[name].json.ts   copied from schema/
    components/           Hero, Glance (the live demo), Tile (draws every panel type), sections
    data/                 sample output for every tile, close to the shape a script prints
    lib/                  reading docs/ and schema/, small Markdown and chart helpers
    styles/global.css     tokens from the prototype and the tile styles
```

Tiles are drawn in `--u`, one app point. The hero sets it from the screen's width (`100cqw / 1280`), so the whole desktop scales as one picture.

## Commands

```sh
pnpm install
pnpm dev        # http://localhost:4321, ?glance=open keeps the glance open
pnpm check      # vp check (format, lint) and astro check (types)
pnpm build      # dist/
```

To update `public/og.png`, open `/og` at 1200×630 and screenshot it.

## Deploy

Cloudflare Pages: root directory `site`, build `pnpm build`, output `dist`, `NODE_VERSION=24`. The build reads `../docs` and `../schema`, so it needs the whole repo, which Pages clones anyway. Custom domain `tjuvkik.banjoanton.com` (a CNAME in the banjoanton.com zone). Turn on Web Analytics in the Pages project; it adds its own beacon, so the site has no snippet.

## Before launch

- Make `banjo/tjuvkik` public and add an MIT `LICENSE`.
- Check every CTA link, and that `llms.txt` links resolve once the repo is public.
