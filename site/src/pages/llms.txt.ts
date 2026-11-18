import type { APIRoute } from "astro";
import { site } from "../data/site";
import { docMarkdownPath } from "../lib/doc-links";
import { docGroups } from "../lib/docs";
import { schemas } from "../lib/repo";

export const GET: APIRoute = async () => {
  const groups = await docGroups();
  const docLinks = groups
    .map(
      (g) =>
        `## ${g.title === "Guide" ? "Docs" : g.title}\n\n` +
        g.pages
          .map(
            (p) =>
              `- [${p.label}](${site.url}${docMarkdownPath(p.id)})${p.description ? `: ${p.description}` : ""}`,
          )
          .join("\n"),
    )
    .join("\n\n");
  const schemaLinks = schemas()
    .map((name) => `- [${name}](${site.url}/schema/${name}.json)`)
    .join("\n");

  const body = `# Tjuvkik

> A glanceable, scriptable dashboard for macOS. Hold fn to show a board of panels over whatever you're doing; let go and it's gone. Every panel is a command: it prints JSON (or plain text) and Tjuvkik draws it as rows, a chart, a table, a timeline, a feed and more. Configured as plain files in ~/.config/tjuvkik.

- Native Swift app for macOS 15 or later, free and open source (MIT): ${site.repo}
- Config: ~/.config/tjuvkik/config.jsonc, a folder per panel in panels/<name>/ with panel.jsonc and its script, themes in themes/.
- Command line: \`tjuvkik new <name> --type <type>\` makes a panel, \`tjuvkik run <name>\` runs it and says what the tile shows, \`tjuvkik preview <name>\` renders the tile to a PNG, \`tjuvkik validate\` checks the folder and exits 1 on errors.
- Docs for people: ${site.url}/docs/. Every page is also Markdown: add .md to its path, like ${site.url}/docs/config.md.
- Every doc in one file: ${site.url}/llms-full.txt

${docLinks}

## JSON Schemas

${schemaLinks}
`;

  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
