/// Written to `config.json` on first run.
public enum DefaultConfig {
    public static let text = """
    // Tjuvkik: hold fn to glance. This file is reloaded when you save it.
    // Comments and trailing commas are fine. Errors show in the menu bar menu.
    {
      "$schema": "./config.schema.json",

      // "bento" for now. "spotlight" comes later.
      "view": "bento",
      // "framed" for now. "fullscreen" and "edges" come later.
      "layout": "framed",
      // "dark-glass", "light-glass", "dracula", or one of your own in "themes".
      "theme": "dark-glass",

      // How long to hold fn before the glance shows.
      "trigger": { "holdMs": 250 },
      "launchAtLogin": true,

      // Your own themes: extend one and override any token.
      "themes": {
        // "mine": { "extends": "dracula", "accent": "#ff79c6" },
      },

      // Tiles fill a 4×3 grid in order. Sizes: s 1×1, m 2×1, l 2×2, xl 2×3.
      "tiles": [
        { "module": "agents", "size": "xl" },
        // A script prints rows as JSON:
        // { "type": "script", "title": "GitHub", "size": "s", "every": "5m", "command": "~/.config/tjuvkik/modules/github.sh" },
        // A cli tile shows a command's output as is:
        { "type": "cli", "title": "Disk", "size": "m", "every": "5m", "command": "df -h /" },
      ],
    }

    """
}
