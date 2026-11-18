import type { Panel } from "./types";

const wave = (n: number, base: number, amp: number, seed: number, trend = 0) =>
  Array.from({ length: n }, (_, i) =>
    Math.max(
      0,
      base +
        Math.sin(i * 0.45 + seed) * amp +
        Math.sin(i * 1.7 + seed * 2) * amp * 0.45 +
        (i / n) * trend,
    ),
  );

export const agents: Panel = {
  title: "Agents",
  kind: "script",
  every: "live",
  content: {
    type: "rows",
    summary: [
      { value: "2", label: "need you", tone: "warning" },
      { value: "1", label: "working", tone: "accent" },
      { value: "1", label: "done", tone: "info" },
    ],
    rows: [
      {
        icon: "✋",
        title: "Fix flaky login test",
        subtitle: "web:2 · claude",
        trailing: "3m",
        tone: "warning",
        note: "Allow: npm run test:e2e?",
      },
      {
        icon: "❌",
        title: "Migrate billing to v2 API",
        subtitle: "api:1 · codex",
        trailing: "12m",
        tone: "error",
        note: "Build failed: 2 type errors",
      },
      {
        icon: "⚙️",
        title: "Write release notes",
        subtitle: "docs:1 · opencode",
        trailing: "working",
        tone: "accent",
      },
      {
        icon: "✅",
        title: "Bump dependencies",
        subtitle: "web:3 · claude",
        trailing: "1h",
        tone: "info",
      },
      {
        icon: "💤",
        title: "Refactor settings page",
        subtitle: "app:1 · claude",
        trailing: "2h",
        tone: "muted",
      },
    ],
  },
};

export const pullRequests: Panel = {
  title: "Pull requests",
  kind: "script",
  every: "5m",
  content: {
    type: "rows",
    hero: { value: "2", label: "reviews requested", tone: "warning" },
    rows: [
      {
        icon: "👀",
        title: "feat: export filters",
        subtitle: "acme/web #1284",
        trailing: "1h",
        tone: "warning",
      },
      {
        icon: "👀",
        title: "fix: retry webhook delivery",
        subtitle: "acme/api #812",
        trailing: "3h",
        tone: "warning",
      },
      {
        icon: "🔀",
        title: "chore: move to pnpm 12",
        subtitle: "acme/web #1279",
        trailing: "1d",
        tone: "muted",
      },
    ],
  },
};

export const ci: Panel = {
  title: "CI · main",
  kind: "grid",
  every: "30s",
  content: {
    type: "grid",
    items: [
      { label: "lint", value: "41s", tone: "success" },
      { label: "types", value: "1:02", tone: "success" },
      { label: "unit", value: "2:48", tone: "success" },
      { label: "e2e", value: "failed", tone: "error" },
      { label: "build", value: "1:55", tone: "success" },
      { label: "deploy", value: "queued", tone: "accent" },
      { label: "audit", value: "2 warn", tone: "warning" },
      { label: "docs", value: "38s", tone: "success" },
      { label: "preview", value: "ready", tone: "info" },
    ],
  },
};

export const cpu: Panel = {
  title: "CPU",
  kind: "chart",
  every: "5s",
  content: {
    type: "chart",
    value: "64",
    unit: "%",
    delta: { text: "▲ 22 in 10m", tone: "warning" },
    series: wave(40, 30, 10, 1, 12).map((v, i) => (i > 32 ? v + (i - 32) * 2.2 : v)),
    tone: "accent",
    min: 0,
    max: 100,
  },
};

export const memory: Panel = {
  title: "Memory",
  kind: "meters",
  every: "5s",
  content: {
    type: "meters",
    meters: [
      { label: "Memory", value: 28, max: 32, text: "28 GB", of: "32", tone: "warning" },
      { label: "Disk", value: 412, max: 494, text: "412 GB", of: "494", mark: 91, tone: "accent" },
      { label: "Battery", value: 78, max: 100, text: "78%", tone: "success" },
    ],
  },
};

export const deploys: Panel = {
  title: "Deploys this week",
  kind: "timeline",
  every: "15m",
  content: {
    type: "timeline",
    from: 0,
    to: 5,
    now: 2.55,
    events: [
      { title: "web 3.14", start: 0.1, end: 0.8, tone: "success" },
      { title: "api 2.9", start: 1.2, end: 1.9, tone: "success" },
      { title: "freeze", start: 2.3, end: 3.4, tone: "warning" },
      { title: "prod", start: 3.6, end: 4.6, tone: "accent" },
    ],
    ticks: [
      [0.5, "Mon"],
      [1.5, "Tue"],
      [2.5, "Wed"],
      [3.5, "Thu"],
      [4.5, "Fri"],
    ],
    notes: [
      { k: "Now", title: "Code freeze", sub: "until Thu 10:00" },
      { k: "Next", title: "Prod window", sub: "Thu 14:00" },
    ],
  },
};

export const pods: Panel = {
  title: "Pods",
  kind: "cli",
  every: "30s",
  content: {
    type: "cli",
    text: `NAME                      READY   STATUS             RESTARTS   AGE
api-7d9f4-x2kq            1/1     Running            0          2d
api-7d9f4-p8vn            1/1     Running            0          2d
export-1794-lq            0/1     CrashLoopBackOff   12         41m
web-5c88b-r7t2            1/1     Running            0          6h
worker-6b2-h5c            1/1     Running            1          1d`,
  },
};

/** The board in the hero, in the app's 4×3 grid. */
export const heroBoard: { panel: Panel; area: string }[] = [
  { panel: agents, area: "1 / 1 / 3 / 3" },
  { panel: pullRequests, area: "1 / 3 / 2 / 5" },
  { panel: cpu, area: "2 / 3 / 3 / 4" },
  { panel: memory, area: "2 / 4 / 3 / 5" },
  { panel: pods, area: "3 / 1 / 4 / 3" },
  { panel: ci, area: "3 / 3 / 4 / 5" },
];

/** A PR panel with a row picked, for the actions example. */
export const prActions: Panel = {
  title: "Pull requests",
  kind: "script",
  every: "5m",
  content: {
    type: "rows",
    hero: { value: "2", label: "reviews requested", tone: "warning" },
    rows: [
      {
        icon: "👀",
        title: "feat: export filters",
        subtitle: "acme/web #1284",
        trailing: "1h",
        tone: "warning",
        selected: true,
      },
      {
        icon: "👀",
        title: "fix: retry webhook delivery",
        subtitle: "acme/api #812",
        trailing: "3h",
        tone: "warning",
      },
      {
        icon: "🔀",
        title: "chore: move to pnpm 12",
        subtitle: "acme/web #1279",
        trailing: "1d",
        tone: "muted",
      },
      {
        icon: "📝",
        title: "wip: dark mode tokens",
        subtitle: "acme/design #77",
        trailing: "2d",
        tone: "muted",
      },
    ],
  },
};

export interface GalleryEntry {
  type: string;
  blurb: string;
  panel: Panel;
}

export const gallery: GalleryEntry[] = [
  {
    type: "rows",
    blurb: "A list with icons, tones, groups and a note for what needs you.",
    panel: pullRequests,
  },
  {
    type: "cli",
    blurb: "Any command's output as is. No JSON needed.",
    panel: {
      title: "git status",
      kind: "cli",
      every: "10s",
      content: {
        type: "cli",
        text: `On branch feat/export-filters
Your branch is ahead of 'origin' by 2 commits.

Changes not staged for commit:
  modified:   src/export/filters.ts
  modified:   src/export/filters.test.ts

Untracked files:
  src/export/presets.ts`,
      },
    },
  },
  {
    type: "stats",
    blurb: "A few numbers, each against its last period.",
    panel: {
      title: "GitHub this week",
      kind: "stats",
      every: "1h",
      content: {
        type: "stats",
        columns: 2,
        stats: [
          { label: "Merged", value: "12", delta: "▲ 4", tone: "success", vs: "vs last" },
          { label: "Reviews given", value: "19", delta: "▲ 7", tone: "success", vs: "vs last" },
          {
            label: "Time to review",
            value: "3.2",
            unit: "h",
            delta: "▲ 1.1h",
            tone: "warning",
            vs: "median",
          },
          { label: "Open PRs", value: "7", delta: "±0", tone: "muted", vs: "2 drafts" },
        ],
      },
    },
  },
  {
    type: "chart",
    blurb: "One number and where it's heading.",
    panel: {
      title: "API latency",
      kind: "chart",
      every: "1m",
      content: {
        type: "chart",
        value: "182",
        unit: "ms",
        label: "p95, api prod",
        delta: { text: "▼ 24ms in 1h", tone: "success" },
        series: wave(40, 200, 14, 6, -30),
        tone: "success",
      },
    },
  },
  {
    type: "meters",
    blurb: "How full, how far, how close to a limit.",
    panel: {
      title: "API quotas",
      kind: "meters",
      every: "5m",
      content: {
        type: "meters",
        meters: [
          { label: "GitHub", value: 4212, max: 5000, text: "4,212", of: "5,000", tone: "warning" },
          { label: "OpenAI", value: 31, max: 50, text: "$31", of: "$50", mark: 80, tone: "accent" },
          { label: "Sentry", value: 12, max: 50, text: "12k", of: "50k", tone: "success" },
        ],
        footer: "Resets in 3 days",
      },
    },
  },
  {
    type: "table",
    blurb: "The same fields for every row, in columns.",
    panel: {
      title: "Top processes",
      kind: "table",
      every: "5s",
      content: {
        type: "table",
        columns: [
          { title: "Process", width: "44%" },
          { title: "CPU", align: "right" },
          { title: "Memory", align: "right" },
          { title: "PID", align: "right" },
        ],
        rows: [
          {
            cells: [
              "node (vite)",
              { text: "84%", tone: "warning" },
              "1.2 GB",
              { text: "48211", dim: true },
            ],
          },
          { cells: ["Brave Browser", "31%", "3.4 GB", { text: "1022", dim: true }] },
          { cells: ["opencode", "12%", "640 MB", { text: "33871", dim: true }] },
          { cells: ["Docker", "9%", "4.1 GB", { text: "811", dim: true }] },
          { cells: ["Slack", "3%", "520 MB", { text: "2209", dim: true }] },
        ],
      },
    },
  },
  {
    type: "timeline",
    blurb: "What's now, what's next, and how long until.",
    panel: {
      ...deploys,
      content: {
        ...(deploys.content as Extract<Panel["content"], { type: "timeline" }>),
        countdown: {
          label: "Prod window in",
          when: "1d 4h",
          what: "Thu 14:00 · api 2.10, web 3.15",
          tone: "accent",
        },
      },
    },
  },
  {
    type: "feed",
    blurb: "Who said what, and when. Unread marked.",
    panel: {
      title: "Mentions",
      kind: "feed",
      every: "1m",
      content: {
        type: "feed",
        items: [
          {
            author: "Sara Lind",
            initials: "SL",
            tone: "warning",
            where: "#web",
            text: "Can you look at the **export PR** before the demo?",
            time: "28m",
            unread: true,
          },
          {
            author: "GitHub",
            icon: "👀",
            where: "acme/web #1284",
            text: "**Johan** requested your review on **feat: export filters**",
            time: "1h",
            unread: true,
          },
          {
            author: "Kim Ek",
            initials: "KE",
            tone: "info",
            where: "DM",
            text: "Nice work on the calendar fix 🙌",
            time: "Sun",
          },
        ],
      },
    },
  },
  {
    type: "grid",
    blurb: "Many things at once, a colored cell each.",
    panel: {
      title: "Uptime, 24h",
      kind: "grid",
      every: "5m",
      content: {
        type: "grid",
        items: [
          { label: "web", value: "100%", tone: "success" },
          { label: "api", value: "99.2%", tone: "warning" },
          { label: "auth", value: "100%", tone: "success" },
          { label: "search", value: "down", tone: "error" },
          { label: "cdn", value: "100%", tone: "success" },
          { label: "queue", value: "100%", tone: "success" },
          { label: "mail", value: "100%", tone: "success" },
          { label: "billing", value: "100%", tone: "success" },
          { label: "docs", value: "100%", tone: "success" },
        ],
      },
    },
  },
  {
    type: "keyvalue",
    blurb: "Exact facts, grouped. Know where you are before you run it.",
    panel: {
      title: "Environment",
      kind: "keyvalue",
      every: "30s",
      content: {
        type: "keyvalue",
        pairs: [
          { section: "Kubernetes" },
          { key: "Context", value: "prod-eu-west", tone: "error", pill: true },
          { key: "Namespace", value: "web" },
          { section: "Repo" },
          { key: "Branch", value: "feat/export-filters" },
          { key: "Node", value: "v24.15.0" },
          { key: "Uncommitted", value: "3 files", tone: "warning" },
        ],
      },
    },
  },
  {
    type: "checklist",
    blurb: "Steps, and what's done, next and stuck.",
    panel: {
      title: "Release 5.3",
      kind: "checklist",
      every: "5m",
      content: {
        type: "checklist",
        caption: "steps · release Thu 14:00",
        items: [
          { title: "Freeze main", state: "done" },
          {
            title: "Smoke test on staging",
            state: "doing",
            who: "Sara",
            note: "export and calendar left",
          },
          { title: "Sign-off", state: "blocked", note: "Waiting for Kim, out until Wed" },
          { title: "Deploy to prod", who: "Anton" },
          { title: "Post release notes" },
        ],
      },
    },
  },
  {
    type: "markdown",
    blurb: "Notes, runbooks and answers. Or a file the panel reads.",
    panel: {
      title: "On call",
      kind: "markdown",
      every: "file",
      content: {
        type: "markdown",
        markdown: `### On call this week
**Anton** until Fri 17:00, then **Sara**.

> search is degraded since 11:20.

#### Restart a stuck export
1. Find the job: \`kubectl get jobs\`
2. Delete it, the cron job starts a new one`,
      },
    },
  },
];
