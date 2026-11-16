import Foundation

/// A cheap summary of the config files' modification dates and sizes. Comparing it once a second
/// catches every save, also when stow links the folder or single files into a dotfiles repo,
/// which file system watchers on the link would miss.
public enum ConfigFingerprint {
    public static func of(_ directory: URL) -> String {
        let manager = FileManager.default
        var files = [ConfigFiles.config]
        let themes = directory.appending(path: "themes")
        files += ((try? manager.contentsOfDirectory(atPath: themes.path)) ?? []).filter { $0.hasSuffix(".json") }.map { "themes/\($0)" }
        let panels = directory.appending(path: "panels")
        files += ((try? manager.contentsOfDirectory(atPath: panels.path)) ?? []).map { ConfigFiles.panel($0) }

        return files.sorted().map { file in
            let url = directory.appending(path: file).resolvingSymlinksInPath()
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            return "\(file):\(date):\(values?.fileSize ?? -1)"
        }.joined(separator: "\n")
    }
}
