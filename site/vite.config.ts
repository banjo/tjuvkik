import { defineConfig } from "vite-plus";

export default defineConfig({
  lint: {
    ignorePatterns: ["dist/**", ".astro/**"],
  },
  fmt: {
    ignorePatterns: ["dist/**", ".astro/**", "pnpm-lock.yaml"],
  },
});
