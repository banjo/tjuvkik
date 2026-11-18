import type { APIRoute, GetStaticPaths } from "astro";
import { absoluteLinks } from "../../lib/doc-links";
import { docPages, type DocPage } from "../../lib/docs";

// Every doc as Markdown, at its page's path plus .md, with links that work outside the site.
export const getStaticPaths = (async () =>
  (await docPages()).map((page) => ({
    params: { slug: page.id === "README" ? "index" : page.id },
    props: { page },
  }))) satisfies GetStaticPaths;

export const GET: APIRoute<{ page: DocPage }> = ({ props }) =>
  new Response(absoluteLinks(`${props.page.id}.md`, props.page.doc.body ?? ""), {
    headers: { "Content-Type": "text/markdown; charset=utf-8" },
  });
