import Foundation

/// The files written to an empty config directory on first run.
public enum DefaultConfig {
    public static let files: [(path: String, text: String)] = [
        ("\(ConfigFiles.config).jsonc", config),
        ("\(ConfigFiles.panel("disk")).jsonc", disk),
    ]

    /// Used until the directory has been read.
    public static let fallback = Config(
        view: .bento, layout: .framed, themeName: "dark-glass", theme: .darkGlass,
        holdMilliseconds: 250, launchAtLogin: true,
        tiles: [Tile(panel: "agents", kind: .agents, title: "Agents", size: .xl, every: 1, timeout: 0,
                     slot: GridSlot(column: 0, row: 0, columns: 2, rows: 3))]
    )

    /// Writes the default files that don't exist yet, in either extension.
    public static func write(to directory: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: directory.appending(path: "themes"), withIntermediateDirectories: true)
        for (path, text) in files {
            let url = directory.appending(path: path)
            guard ConfigFiles.locate(String(path.dropLast(".jsonc".count)), in: directory) == nil else { continue }
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static let config = """
    // Tjuvkik: hold fn to glance. Everything in this folder is reloaded when you save it:
    //   config.jsonc               this file: theme, fn, and which panels go where
    //   panels/<name>/panel.jsonc  what a panel shows; its command runs in that folder
    //   themes/<name>.jsonc        your own themes
    // Comments and trailing commas are fine. Errors show in the menu bar menu.
    {
      "$schema": "./schemas/config.schema.json",

      // "bento" for now. "spotlight" comes later.
      "view": "bento",
      // "framed" for now. "fullscreen" and "edges" come later.
      "layout": "framed",
      // "dark-glass", "light-glass", "dracula", or a file in themes/ without its extension.
      "theme": "dark-glass",

      // How long to hold fn before the glance shows.
      "trigger": { "holdMs": 250 },
      "launchAtLogin": true,

      // Panels fill a 4×3 grid in order. "agents" is built in; others are folders in panels/.
      // Sizes: s 1×1, m 2×1, l 2×2, xl 2×3. Leave it out to use the panel's own size.
      "panels": [
        { "panel": "agents", "size": "xl" },
        { "panel": "disk" },
      ],
    }

    """

    static let disk = """
    // A cli panel shows a command's output as is. A script panel prints rows as JSON.
    {
      "$schema": "../../schemas/panel.schema.json",
      "type": "cli",
      "title": "Disk",
      "command": "df -h /",
      "every": "5m",
      "size": "m",
    }

    """
}
