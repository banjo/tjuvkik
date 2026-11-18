import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";
import { rehypeHeadingAnchors, remarkDocLinks } from "./src/lib/doc-links.ts";

export default defineConfig({
  site: "https://tjuvkik.banjoanton.com",
  trailingSlash: "ignore",
  integrations: [sitemap({ filter: (page) => !page.endsWith("/og/") })],
  devToolbar: { enabled: false },
  markdown: {
    shikiConfig: { theme: "dracula" },
    remarkPlugins: [remarkDocLinks],
    rehypePlugins: [rehypeHeadingAnchors],
  },
});
