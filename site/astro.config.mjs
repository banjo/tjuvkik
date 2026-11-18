import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://tjuvkik.banjoanton.com",
  integrations: [sitemap({ filter: (page) => !page.endsWith("/og/") })],
  devToolbar: { enabled: false },
});
