import Foundation
import Observation
import TjuvkikCore

/// What the settings pages share: config.jsonc as text to edit, and the app's config and panels.
@MainActor
@Observable
final class SettingsModel {
    let store: ConfigStore
    let panels: PanelStore
    private(set) var editor: ConfigEditor?
    private(set) var parseError: JSONCDocument.ParseError?
    /// The last change that couldn't be written.
    var writeError: String?
    /// When the trigger last fired, for "Try it".
    var lastTriggered: Date?
    /// Whether Notification Center lets Tjuvkik notify. Set by the app.
    var notificationsDenied = false

    init(store: ConfigStore, panels: PanelStore) {
        self.store = store
        self.panels = panels
        reload()
    }

    /// Reads config.jsonc again. Called on init, when `store.revision` changes, and before each change.
    func reload() {
        let file = store.configFile
        let text: String
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                text = try String(contentsOf: file, encoding: .utf8)
            } catch {
                editor = nil
                parseError = JSONCDocument.ParseError(line: 1, column: 1, message: "can't read the file")
                return
            }
        } else {
            text = "{\n}\n"
        }
        do {
            let editor = try ConfigEditor(text)
            if editor.text != self.editor?.text { self.editor = editor }
            parseError = nil
        } catch {
            editor = nil
            parseError = error
        }
    }

    /// Reads the file, applies `change`, writes it back and reloads the config. `change` throws
    /// `JSONCDocument.ParseError`; closures can't infer a typed throw yet.
    func change(_ change: (inout ConfigEditor) throws -> Void) {
        reload()
        guard parseError == nil, var copy = editor else { return }
        do {
            try change(&copy)
        } catch let error as JSONCDocument.ParseError {
            writeError = "Couldn't change config.jsonc: line \(error.line), column \(error.column): \(error.message)"
            return
        } catch {
            writeError = "Couldn't change config.jsonc: \(error.localizedDescription)"
            return
        }
        guard copy.text != editor?.text else { return }
        do {
            // Through a symlink, so a config folder linked from dotfiles stays linked.
            try copy.text.write(to: store.configFile.resolvingSymlinksInPath(), atomically: true, encoding: .utf8)
            writeError = nil
        } catch {
            writeError = "Couldn't save config.jsonc: \(error.localizedDescription)"
            return
        }
        editor = copy
        store.reload()
    }

    /// The entries in config.jsonc, empty while it can't be parsed.
    var entries: [ConfigEditor.Entry] { editor?.entries() ?? [] }
}
