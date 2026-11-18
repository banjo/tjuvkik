import { readFileSync } from "node:fs";
import { join, posix, relative, sep } from "node:path";

const SITE = "https://tjuvkik.banjoanton.com";
const REPO = "https://github.com/banjo/tjuvkik";

// The site is built from site/, next to the app's docs/.
export const docsDir = join(process.cwd(), "..", "docs");

/** A doc's id ("README", "types/chart") as its page path: "/docs/", "/docs/types/chart/". */
export const docPath = (id: string) => (id === "README" ? "/docs/" : `/docs/${id}/`);

/** A doc's id as the URL of its Markdown: "/docs/index.md", "/docs/types/chart.md". */
export const docMarkdownPath = (id: string) => `/docs/${id === "README" ? "index" : id}.md`;

/**
 * A link in docs/<from> as the site should have it. Links between docs go to their page, or to their
 * Markdown when `markdown` is set; links out of docs/ go to the repo; the rest are left alone.
 */
export function docHref(from: string, href: string, { markdown = false } = {}): string {
  if (/^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith("#") || href.startsWith("/"))
    return href;
  const [path, hash] = href.split("#");
  const target = posix.normalize(posix.join(posix.dirname(from), path));
  const anchor = hash ? `#${hash}` : "";
  if (target.startsWith("../")) return `${REPO}/tree/main/${target.slice(3)}${anchor}`;
  if (target === "types" || target === "types/") return docPath("script-output") + anchor;
  if (/\.(png|jpe?g|svg|webp)$/.test(target)) return `${markdown ? SITE : ""}/docs/${target}`;
  if (target.endsWith(".md")) {
    const id = target.slice(0, -3);
    return markdown ? `${SITE}${docMarkdownPath(id)}${anchor}` : `${docPath(id)}${anchor}`;
  }
  return href;
}

/** Width and height of a PNG, from its header. */
function pngSize(file: string): [number, number] | undefined {
  try {
    const b = readFileSync(file);
    return [b.readUInt32BE(16), b.readUInt32BE(20)];
  } catch {
    return undefined;
  }
}

/** Every Markdown link in `text`, written with docHref, for the .md copies and llms-full.txt. */
export const absoluteLinks = (from: string, text: string) =>
  text.replace(
    /\]\(([^)\s]+)\)/g,
    (_, href: string) => `](${docHref(from, href, { markdown: true })})`,
  );

interface Node {
  type: string;
  url?: string;
  data?: Record<string, unknown>;
  tagName?: string;
  properties?: Record<string, unknown>;
  children?: Node[];
}

const walk = (node: Node, fn: (n: Node) => void) => {
  fn(node);
  node.children?.forEach((c) => walk(c, fn));
};

const docOf = (file: { path?: string; history?: string[] }) => {
  const path = file.path ?? file.history?.[0];
  if (!path) return;
  const rel = relative(docsDir, path);
  return rel.startsWith("..") ? undefined : rel.split(sep).join("/");
};

/** Remark: rewrite links in docs/ to the site's pages, and drop the title, which the page draws itself. */
export const remarkDocLinks = () => (tree: Node, file: { path?: string; history?: string[] }) => {
  const from = docOf(file);
  if (!from) return;
  const title = tree.children?.findIndex(
    (n) => n.type === "heading" && (n as { depth?: number }).depth === 1,
  );
  if (title !== undefined && title >= 0) tree.children?.splice(title, 1);
  walk(tree, (n) => {
    if (n.type === "link" && n.url) n.url = docHref(from, n.url);
    if (n.type === "image" && n.url && !/^[a-z]+:|^\//i.test(n.url)) {
      // Served as is from docs/ (see pages/docs/[...path].png.ts), not through Astro's image pipeline.
      // Previews are rendered at 2x, so they're drawn at half their pixel size.
      const size = pngSize(join(docsDir, posix.dirname(from), n.url));
      n.url = docHref(from, n.url);
      n.data = {
        hProperties: {
          loading: "lazy",
          decoding: "async",
          ...(size && { width: size[0] / 2, height: size[1] / 2 }),
        },
      };
    }
  });
};

/** Rehype: a "#" link after every h2 and h3, and a class on paragraphs that are only images. */
export const rehypeHeadingAnchors = () => (tree: Node) => {
  walk(tree, (n) => {
    if (n.type === "element" && n.tagName === "p") {
      const kids = (n.children ?? []).filter(
        (c) => !(c.type === "text" && !(c as { value?: string }).value?.trim()),
      );
      if (kids.length && kids.every((c) => c.tagName === "img"))
        n.properties = { ...n.properties, className: ["shots"] };
    }
    if (n.type !== "element" || (n.tagName !== "h2" && n.tagName !== "h3")) return;
    const id = n.properties?.id;
    if (typeof id !== "string") return;
    n.children = [
      ...(n.children ?? []),
      {
        type: "element",
        tagName: "a",
        properties: {
          className: ["anchor"],
          href: `#${id}`,
          ariaLabel: "Link to this section",
          dataPagefindIgnore: "",
        },
        children: [{ type: "text", value: "#" } as Node],
      },
    ];
  });
};
