export const site = {
  name: "Tjuvkik",
  url: "https://tjuvkik.banjoanton.com",
  repo: "https://github.com/banjo/tjuvkik",
  // TODO: not live until the site is deployed; then point the app's written configs and starters here too.
  schema: (name: "config" | "panel" | "theme") =>
    `https://tjuvkik.banjoanton.com/schema/${name}.schema.json`,
  title: "Tjuvkik: a glanceable, scriptable dashboard for macOS",
  description:
    "Hold fn to glance at your builds, pull requests, AI coding agents and anything else you can script. A native macOS dashboard configured as code. Let go and it's gone.",
};
