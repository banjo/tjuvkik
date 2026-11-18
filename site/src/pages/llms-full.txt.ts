import type { APIRoute } from "astro";
import { site } from "../data/site";
import { absoluteLinks, docMarkdownPath } from "../lib/doc-links";
import { docPages } from "../lib/docs";

export const GET: APIRoute = async () => {
  const body = [
    `# Tjuvkik documentation\n\nEvery page of ${site.url}/docs/ in one file. Each page starts with its URL.`,
    ...(await docPages()).map(
      (p) =>
        `<!-- ${site.url}${docMarkdownPath(p.id)} -->\n\n${absoluteLinks(`${p.id}.md`, p.doc.body ?? "").trim()}`,
    ),
  ].join("\n\n---\n\n");

  return new Response(`${body}\n`, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
