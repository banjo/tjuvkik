import type { APIRoute } from "astro";
import { site } from "../data/site";
import { docs, schemas } from "../lib/repo";

const title = (text: string, fallback: string) => text.match(/^# (.+)$/m)?.[1] ?? fallback;

export const GET: APIRoute = () => {
  const docLinks = docs()
    .map(([path, text]) => `- [${title(text, path)}](${site.repo}/blob/main/docs/${path})`)
    .join("\n");
  const schemaLinks = schemas()
    .map((name) => `- [${name}](${site.url}/schema/${name}.json)`)
    .join("\n");

  const body = `# Tjuvkik

> A glanceable, scriptable dashboard for macOS. Hold fn to show a board of panels over whatever you're doing; let go and it's gone. Every panel is a command: it prints JSON (or plain text) and Tjuvkik draws it as rows, a chart, a table, a timeline, a feed and more. Configured as plain files in ~/.config/tjuvkik.

- Native Swift app for macOS 15 or later, free and open source (MIT): ${site.repo}
- Config: ~/.config/tjuvkik/config.jsonc, a folder per panel in panels/<name>/ with panel.jsonc and its script, themes in themes/.
- Command line: \`tjuvkik new <name> --type <type>\` makes a panel, \`tjuvkik run <name>\` runs it and says what the tile shows, \`tjuvkik preview <name>\` renders the tile to a PNG, \`tjuvkik validate\` checks the folder and exits 1 on errors.
- Every doc in one file: ${site.url}/llms-full.txt

## Docs

${docLinks}

## JSON Schemas

${schemaLinks}
`;

  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
