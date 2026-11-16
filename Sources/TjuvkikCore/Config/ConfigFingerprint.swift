import Foundation

/// A cheap summary of the config files' modification dates and sizes. Comparing it once a second
/// catches every save, also when stow links the folder or single files into a dotfiles repo,
/// which file system watchers on the link would miss.
public enum ConfigFingerprint {
    public static func of(_ directory: URL) -> String {
        let manager = FileManager.default
        let themes = directory.appending(path: "themes")
        let panels = directory.appending(path: "panels")
        let names = [ConfigFiles.config]
            + ((try? manager.contentsOfDirectory(atPath: themes.path)) ?? []).map { "themes/\($0)" }
            + ((try? manager.contentsOfDirectory(atPath: panels.path)) ?? []).map { ConfigFiles.panel($0) }
        let files = names.flatMap { name in
            ConfigFiles.extensions.contains { name.hasSuffix(".\($0)") } ? [name] : ConfigFiles.extensions.map { "\(name).\($0)" }
        }

        return files.sorted().map { file in
            let url = directory.appending(path: file).resolvingSymlinksInPath()
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(file):\(date):\(values?.fileSize ?? -1)"
        }.joined(separator: "\n")
    }
}
