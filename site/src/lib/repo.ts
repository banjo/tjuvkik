import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

// The site lives in site/ of the app's repo; schemas are read from there at build time.
const root = join(process.cwd(), "..");

export const schemaDir = join(root, "schema");

export function schemas(): string[] {
  return readdirSync(schemaDir)
    .filter((f) => f.endsWith(".schema.json"))
    .map((f) => f.replace(/\.json$/, ""));
}

export function schema(name: string): string {
  return readFileSync(join(schemaDir, `${name}.json`), "utf8");
}
