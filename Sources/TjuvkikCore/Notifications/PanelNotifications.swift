import Foundation

/// The notifications a panel asks for right now: what its script printed in `notify`, plus
/// what its `on` events add.
public enum PanelNotifications {
    public static func collect(content: ModuleContent?, error: String?, title: String, on: Set<NotifyEvent>) -> [PanelNotification] {
        var result = content?.notify ?? []
        if on.contains(.failed), let error {
            result.append(PanelNotification(id: "tjuvkik:failed", title: "\(title) failed", body: error))
        }
        if case .rows(let rows) = content {
            for row in rows.rows {
                guard let tone = row.tone, let event = NotifyEvent(tone: tone), on.contains(event) else { continue }
                result.append(PanelNotification(
                    id: "tjuvkik:row:\(tone.rawValue):\(row.title)\u{1F}\(row.subtitle ?? "")",
                    title: row.title, subtitle: title, body: row.note ?? row.subtitle,
                    url: row.url, command: row.command
                ))
            }
        }
        // The first of each id wins, so a script can't send one twice.
        var seen: Set<String> = []
        return result.filter { seen.insert($0.id).inserted }
    }
}
