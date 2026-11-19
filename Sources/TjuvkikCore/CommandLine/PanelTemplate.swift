import Foundation

/// The files `tjuvkik new` writes: a panel.jsonc and a script that prints an example of the
/// panel's type, to edit from there.
public enum PanelTemplate {
    public struct File: Equatable, Sendable {
        /// Relative to the config folder.
        public var path: String
        public var text: String
        public var executable: Bool
    }

    /// `script` prints rows, `cli` prints plain text, and a content type prints that type.
    public static let types = ["script", "cli"] + ContentType.allCases.map(\.rawValue)

    /// Folder names that work everywhere a panel is named: letters, digits, `-` and `_`.
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix("-") && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    public static func files(name: String, type: String) -> [File] {
        let content = ContentType(rawValue: type)
        // Rows and a chart read well small; the rest want the room of an m.
        let size = content == .chart || type == "script" ? "1x1" : "2x1"
        let panel = """
        {
          "$schema": "../../schemas/panel.schema.json",
          "description": "",
          "type": "\(type)",
          "title": "\(title(name))",
          "command": "./\(name).sh",
          "every": "60s",
          "size": "\(size)",
        }

        """
        let script: String
        if type == "cli" {
            script = """
            #!/bin/sh
            # Prints what the tile shows, as is. Runs in this folder, with your login shell's PATH.
            # See docs/panels.md.
            uptime

            """
        } else {
            let doc = content.map { "docs/types/\($0.rawValue).md" } ?? "docs/script-output.md"
            script = """
            #!/bin/sh
            # Prints the tile's content as JSON. Runs in this folder, with your login shell's PATH.
            # Try it with `tjuvkik run \(name)`. The format: \(doc).
            cat <<'EOF'
            \(sample(content))
            EOF

            """
        }
        return [
            File(path: "panels/\(name)/panel.jsonc", text: panel, executable: false),
            File(path: "panels/\(name)/\(name).sh", text: script, executable: true),
        ]
    }

    /// "release-notes" → "Release notes".
    static func title(_ name: String) -> String {
        let words = name.replacing("-", with: " ").replacing("_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// A small example of each type's output.
    public static func sample(_ type: ContentType?) -> String {
        switch type {
        case nil:
            """
            {
              "summary": [{ "icon": "●", "value": "2", "label": "open", "tone": "warning" }],
              "rows": [
                { "icon": "●", "title": "First row", "subtitle": "what it is", "trailing": "2m", "tone": "warning" },
                { "icon": "○", "title": "Second row", "trailing": "1h" }
              ]
            }
            """
        case .chart:
            """
            {
              "chart": {
                "value": 64, "unit": "%", "label": "CPU",
                "delta": { "text": "▲ 12 pts", "tone": "warning" },
                "series": [31, 28, 35, 30, 41, 52, 64],
                "min": 0, "max": 100
              }
            }
            """
        case .meters:
            """
            {
              "meters": [
                { "label": "Disk", "value": 412, "max": 494, "text": "412 GB", "of": "494 GB", "tone": "warning" },
                { "label": "Memory", "value": 21, "max": 32, "text": "21 GB", "of": "32 GB" }
              ]
            }
            """
        case .grid:
            """
            {
              "grid": {
                "rows": [
                  { "label": "api", "value": "100%", "cells": ["success", "success", "success", "success"] },
                  { "label": "web", "value": "98.5%", "cells": ["success", "warning", "success", "success"] }
                ]
              }
            }
            """
        case .timeline:
            """
            {
              "timeline": {
                "from": "09:00", "to": "17:00",
                "events": [
                  { "title": "Standup", "start": "09:15", "end": "09:30", "tone": "info" },
                  { "title": "Focus time", "start": "13:00", "end": "15:00", "tone": "success" }
                ]
              }
            }
            """
        case .stats:
            """
            {
              "stats": [
                { "label": "Open", "value": 12, "delta": "▲ 3", "tone": "warning", "vs": "vs last week" },
                { "label": "Closed", "value": 30, "delta": "▲ 8", "tone": "success", "vs": "vs last week" }
              ]
            }
            """
        case .markdown:
            """
            {
              "markdown": "### Notes\\n**Bold**, `code` and [links](https://example.com).\\n\\n- One\\n- Two"
            }
            """
        case .keyvalue:
            """
            {
              "pairs": [
                { "key": "Branch", "value": "main" },
                { "key": "Status", "value": "clean", "tone": "success", "pill": true }
              ]
            }
            """
        case .table:
            """
            {
              "columns": [{ "title": "Name" }, { "title": "Status" }, { "title": "Age", "align": "right" }],
              "rows": [
                ["api", { "text": "Running", "tone": "success", "dot": true }, "2d"],
                ["worker", { "text": "Pending", "tone": "warning", "dot": true }, "2m"]
              ]
            }
            """
        case .feed:
            """
            {
              "items": [
                { "author": "Sara Lind", "where": "#team", "text": "Can you look at the **export PR**?", "unread": true },
                { "author": "GitHub", "icon": "👀", "text": "Review requested on **feat: filters**" }
              ]
            }
            """
        case .checklist:
            """
            {
              "items": [
                { "title": "Write it", "state": "done" },
                { "title": "Review it", "state": "doing" },
                { "title": "Ship it" }
              ]
            }
            """
        }
    }
}
