import type { APIRoute } from "astro";
import { site } from "../data/site";
import { docs } from "../lib/repo";

export const GET: APIRoute = () => {
  const body = [
    `# Tjuvkik documentation\n\nEvery page of ${site.repo}/tree/main/docs in one file. Each page starts with its path.`,
    ...docs().map(([path, text]) => `<!-- docs/${path} -->\n\n${text.trim()}`),
  ].join("\n\n---\n\n");

  return new Response(`${body}\n`, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
