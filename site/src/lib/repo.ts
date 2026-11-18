import { readdirSync, readFileSync } from "node:fs";
import { join, relative } from "node:path";

// The site lives in site/ of the app's repo; docs and schemas are read from there at build time.
const root = join(process.cwd(), "..");

export const docsDir = join(root, "docs");
export const schemaDir = join(root, "schema");

/** Every doc as [path from docs/, text], README first, then the order docs/README.md links them in. */
export function docs(): [string, string][] {
  const files: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith(".md")) files.push(relative(docsDir, path));
    }
  };
  walk(docsDir);

  const index = readFileSync(join(docsDir, "README.md"), "utf8");
  const rank = (f: string) => {
    if (f === "README.md") return -1;
    const at = index.indexOf(`(${f})`);
    return at === -1 ? Number.MAX_SAFE_INTEGER : at;
  };
  files.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));
  return files.map((f) => [f, readFileSync(join(docsDir, f), "utf8")]);
}

export function schemas(): string[] {
  return readdirSync(schemaDir)
    .filter((f) => f.endsWith(".schema.json"))
    .map((f) => f.replace(/\.json$/, ""));
}

export function schema(name: string): string {
  return readFileSync(join(schemaDir, `${name}.json`), "utf8");
}
