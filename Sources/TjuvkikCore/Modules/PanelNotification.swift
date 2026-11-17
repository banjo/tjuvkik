import Foundation

/// A notification a panel asks for, in its output's `notify`. Sent once per `id`, and withdrawn
/// when the `id` is gone from the output.
public struct PanelNotification: Equatable, Sendable, Decodable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var body: String?
    /// Opened when it's clicked.
    public var url: String?
    /// Run when it's clicked, in the panel's folder. Wins over `url`.
    public var command: String?

    public init(id: String, title: String, subtitle: String? = nil, body: String? = nil, url: String? = nil, command: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.url = url
        self.command = command
    }
}
