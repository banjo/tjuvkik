import AppKit
import TjuvkikCore
import UniformTypeIdentifiers

/// Export and import of the config folder as a zip, from the menu.
@MainActor
enum ConfigTransfer {
    private static var backups: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Tjuvkik/Backups")
    }

    private static var stamp: String {
        Date().formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted))
            .replacingOccurrences(of: "T", with: "-")
    }

    static func export(_ store: ConfigStore) {
        NSApp.activate()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "tjuvkik-config-\(Date().formatted(.iso8601.year().month().day())).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ConfigArchive.export(store.directory, to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            alert("Couldn't export the config", detail(error))
        }
    }

    static func `import`(_ store: ConfigStore) {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.message = "Choose a Tjuvkik config zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let backup = backups.appending(path: "config-\(stamp).zip")
        let confirm = NSAlert()
        confirm.messageText = "Replace your Tjuvkik config with \(url.lastPathComponent)?"
        confirm.informativeText = "Your current config is saved first as \(backup.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))."
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        do {
            try ConfigArchive.import(url, into: store.directory, backup: backup)
            store.reload()
        } catch {
            alert("Couldn't import the config", detail(error))
        }
    }

    private static func detail(_ error: any Error) -> String {
        switch error as? ConfigArchive.Failure {
        case .command(let output): output
        case .noConfig: "The zip has no config.jsonc."
        case .invalid(let issues): "Nothing was changed. The config in the zip has errors:\n\n" + issues.prefix(8).map(\.description).joined(separator: "\n")
        case nil: error.localizedDescription
        }
    }

    private static func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
