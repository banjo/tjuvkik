// Sample panel output, in the shape a script prints (see docs/script-output.md),
// trimmed to what the page draws.

export type Tone = "normal" | "muted" | "warning" | "error" | "success" | "info" | "accent";

export interface Row {
  icon?: string;
  title: string;
  subtitle?: string;
  trailing?: string;
  tone?: Tone;
  group?: string;
  note?: string;
  selected?: boolean;
}

export interface Chip {
  icon?: string;
  value: string;
  label?: string;
  tone?: Tone;
}

export interface Stat {
  label: string;
  value: string;
  unit?: string;
  delta?: string;
  tone?: Tone;
  vs?: string;
}

export interface Meter {
  label: string;
  value: number;
  max: number;
  text: string;
  of?: string;
  mark?: number;
  tone?: Tone;
}

export type Cell = string | number | { text: string; tone?: Tone; dot?: boolean; dim?: boolean };

export interface Column {
  title: string;
  mono?: boolean;
  width?: string;
  align?: "left" | "right";
}

export interface TimelineEvent {
  title: string;
  start: number;
  end: number;
  tone?: Tone;
}

export interface FeedItem {
  author: string;
  initials?: string;
  icon?: string;
  where?: string;
  text: string;
  time: string;
  unread?: boolean;
  tone?: Tone;
}

export interface GridItem {
  label: string;
  value: string;
  tone: Tone;
}

export type Pair =
  | { section: string }
  | { key: string; value: string; tone?: Tone; pill?: boolean };

export type Task =
  | { section: string }
  | { title: string; state?: "done" | "doing" | "blocked"; who?: string; note?: string };

export type Content =
  | { type: "rows"; hero?: Chip; summary?: Chip[]; progress?: number; rows: Row[] }
  | { type: "cli"; text: string }
  | { type: "stats"; stats: Stat[]; columns?: number }
  | {
      type: "chart";
      value: string;
      unit?: string;
      label?: string;
      delta?: { text: string; tone?: Tone };
      series: number[];
      tone?: Tone;
      threshold?: number;
      min?: number;
      max?: number;
    }
  | { type: "meters"; meters: Meter[]; footer?: string }
  | { type: "table"; columns: Column[]; rows: { cells: Cell[]; highlight?: boolean }[] }
  | {
      type: "timeline";
      from: number;
      to: number;
      now: number;
      events: TimelineEvent[];
      ticks: [number, string][];
      countdown?: { label: string; when: string; what: string; tone?: Tone };
      notes: { k: string; title: string; sub: string }[];
    }
  | { type: "feed"; items: FeedItem[] }
  | { type: "grid"; items: GridItem[] }
  | { type: "keyvalue"; pairs: Pair[] }
  | { type: "checklist"; items: Task[]; caption?: string }
  | { type: "markdown"; markdown: string };

export interface Panel {
  title: string;
  /** The tag on the tile: the panel's type. */
  kind: string;
  /** "60s", or "live" for a stream. */
  every: string;
  content: Content;
}
