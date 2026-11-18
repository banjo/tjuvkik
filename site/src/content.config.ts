import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";

// The app's docs/, as they are in the repo. Ids keep the path: "README", "config", "types/chart".
const docs = defineCollection({
  loader: glob({
    base: "../docs",
    pattern: "**/*.md",
    generateId: ({ entry }) => entry.replace(/\.md$/, ""),
  }),
});

export const collections = { docs };
