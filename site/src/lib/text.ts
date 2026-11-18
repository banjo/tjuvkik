const escape = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/** `**bold**` and `` `code` ``, the inline Markdown the app draws in feeds and notes. */
export function inline(s: string): string {
  return escape(s)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/`(.+?)`/g, "<code>$1</code>");
}

/** The small part of Markdown the sample markdown panel uses: headings, quotes, ordered lists, paragraphs. */
export function markdown(src: string): string {
  const out: string[] = [];
  let list: string[] = [];
  const flush = () => {
    if (list.length) out.push(`<ol>${list.map((li) => `<li>${inline(li)}</li>`).join("")}</ol>`);
    list = [];
  };
  for (const line of src.split("\n")) {
    const ordered = line.match(/^\d+\.\s+(.*)$/);
    if (ordered) {
      list.push(ordered[1]);
      continue;
    }
    flush();
    if (!line.trim()) continue;
    if (line.startsWith("#### ")) out.push(`<h4>${inline(line.slice(5))}</h4>`);
    else if (line.startsWith("### ")) out.push(`<h3>${inline(line.slice(4))}</h3>`);
    else if (line.startsWith("> ")) out.push(`<blockquote>${inline(line.slice(2))}</blockquote>`);
    else out.push(`<p>${inline(line)}</p>`);
  }
  flush();
  return out.join("");
}

/** An SVG path through `series`, scaled to w × h. */
export function linePath(series: number[], w: number, h: number, lo: number, hi: number): string {
  const step = w / (series.length - 1);
  const y = (v: number) => h - ((v - lo) / (hi - lo)) * h;
  return series
    .map((v, i) => `${i ? "L" : "M"}${(i * step).toFixed(1)} ${y(v).toFixed(1)}`)
    .join(" ");
}
