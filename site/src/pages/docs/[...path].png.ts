import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { APIRoute, GetStaticPaths } from "astro";
import { docsDir } from "../../lib/doc-links";

// The images in docs/, like types/images/chart-2x1.png, at the same path under /docs/.
export const getStaticPaths = (() =>
  readdirSync(docsDir, { recursive: true, encoding: "utf8" })
    .filter((f) => f.endsWith(".png"))
    .map((f) => ({ params: { path: f.slice(0, -4) } }))) satisfies GetStaticPaths;

export const GET: APIRoute = ({ params }) =>
  new Response(readFileSync(join(docsDir, `${params.path}.png`)), {
    headers: { "Content-Type": "image/png" },
  });
