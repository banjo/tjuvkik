import { getCollection, type CollectionEntry } from "astro:content";

export type Doc = CollectionEntry<"docs">;

export interface DocPage {
  id: string;
  title: string;
  /** The name in the sidebar. */
  label: string;
  description: string;
  doc: Doc;
}

export interface DocGroup {
  title: string;
  pages: DocPage[];
}

const heading = (body: string) => body.match(/^# (.+)$/m)?.[1]?.trim();

const plain = (s: string) =>
  s
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/[`*_]/g, "")
    .replace(/\s+/g, " ")
    .trim();

/** The first paragraph after the title, as plain text, for the meta description. */
function firstParagraph(body: string): string {
  // Prose only: not headings, code, tables, lists, or a sentence that leads into a code block.
  const paragraphs = body
    .replace(/```[\s\S]*?```/g, "")
    .split(/\n\s*\n/)
    .map((b) => b.trim())
    .filter((b) => b && !/^(#|\||>|- |\d+\. )/.test(b));
  const text = plain(paragraphs.find((b) => !b.endsWith(":")) ?? paragraphs[0] ?? "");
  return text.length > 160 ? `${text.slice(0, 157).replace(/\s+\S*$/, "")}…` : text;
}

/** Ids in the order `text` links to them, like "(install.md)" or "(types/chart.md)". */
const linkOrder = (text: string, prefix = "") =>
  [...text.matchAll(/\]\(([\w/-]+)\.md\)/g)].map((m) => prefix + m[1]);

/** The docs in two groups, in the order docs/README.md and script-output.md list them. */
export async function docGroups(): Promise<DocGroup[]> {
  const all = await getCollection("docs");
  const byId = new Map(all.map((d) => [d.id, d]));
  // docs/README.md says what each guide page is for: "[Install](install.md): build, first start, …".
  const blurbs = new Map(
    [...(byId.get("README")?.body ?? "").matchAll(/\]\(([\w/-]+)\.md\):\s*(.+)$/gm)].map((m) => {
      // Capitalise "build, …" but not "`config.jsonc`, …" or "macOS …".
      const raw = m[2].trim();
      const text = plain(raw);
      const upper = /^[a-z]/.test(raw) && !/^macOS\b/.test(raw);
      return [m[1], upper ? text.charAt(0).toUpperCase() + text.slice(1) : text] as const;
    }),
  );
  const page = (id: string): DocPage | undefined => {
    const doc = byId.get(id);
    if (!doc) return;
    const title = id === "README" ? "Overview" : (heading(doc.body ?? "") ?? id);
    return {
      id,
      title: id === "README" ? "Tjuvkik docs" : title,
      label: title,
      description:
        id === "README"
          ? "How to install, configure and script Tjuvkik, the glanceable macOS dashboard."
          : (blurbs.get(id) ?? firstParagraph(doc.body ?? "")),
      doc,
    };
  };

  const guideIds = ["README", ...linkOrder(byId.get("README")?.body ?? "")];
  const typeIds = linkOrder(byId.get("script-output")?.body ?? "").filter((id) =>
    id.startsWith("types/"),
  );
  const rest = all
    .map((d) => d.id)
    .filter((id) => !guideIds.includes(id) && !typeIds.includes(id))
    .sort();

  const pages = (ids: string[]) => ids.map(page).filter((p): p is DocPage => !!p);
  return [
    {
      title: "Guide",
      pages: pages([...guideIds, ...rest.filter((id) => !id.startsWith("types/"))]),
    },
    {
      title: "Panel types",
      pages: pages([...typeIds, ...rest.filter((id) => id.startsWith("types/"))]),
    },
  ];
}

export async function docPages(): Promise<DocPage[]> {
  return (await docGroups()).flatMap((g) => g.pages);
}
