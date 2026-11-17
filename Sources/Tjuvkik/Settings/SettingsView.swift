import AppKit
import SwiftUI
import TjuvkikCore

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, board, panels, theme

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .board: "Board"
        case .panels: "Panels"
        case .theme: "Theme"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .board: "square.grid.2x2"
        case .panels: "shippingbox"
        case .theme: "paintpalette"
        }
    }
}

/// A sidebar of pages, each editing part of config.jsonc.
struct SettingsView: View {
    let model: SettingsModel
    @AppStorage("settingsPage") private var page = SettingsPage.board

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: Binding($page)) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            VStack(spacing: 0) {
                SettingsBanner(model: model)
                Group {
                    switch page {
                    case .general: GeneralPage(model: model)
                    case .board: BoardPage(model: model)
                    case .panels: PanelsPage(model: model)
                    case .theme: ThemePage(model: model)
                    }
                }
                .disabled(model.parseError != nil)
            }
        }
        .onChange(of: model.store.revision) { model.reload() }
    }
}

/// The file's state, above every page: why it can't be parsed, what's wrong in it, or why the
/// last change couldn't be saved.
struct SettingsBanner: View {
    let model: SettingsModel

    var body: some View {
        let file = model.store.configFile.lastPathComponent
        VStack(alignment: .leading, spacing: 6) {
            if let error = model.parseError {
                HStack {
                    Label("\(file) line \(error.line), column \(error.column): \(error.message)", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Open in Editor") { NSWorkspace.shared.open(model.store.configFile) }
                }
            } else if !model.store.errors.isEmpty {
                Label("Config error, using the last good config:", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                ForEach(Array(model.store.errors.prefix(8).enumerated()), id: \.offset) { _, issue in
                    Text(issue.description).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            if let error = model.writeError {
                Label(error, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, hasContent ? 12 : 0)
        .background(hasContent ? AnyShapeStyle(.bar) : AnyShapeStyle(.clear))
    }

    private var hasContent: Bool {
        model.parseError != nil || !model.store.errors.isEmpty || model.writeError != nil
    }
}

/// Opens a file in its editor, or shows it in Finder.
enum SettingsFiles {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// `panels/<name>/panel.jsonc`, or `.json`.
    static func panelFile(_ name: String, in directory: URL) -> URL {
        directory.appending(path: ConfigFiles.locate(ConfigFiles.panel(name), in: directory) ?? "\(ConfigFiles.panel(name)).jsonc")
    }
}
