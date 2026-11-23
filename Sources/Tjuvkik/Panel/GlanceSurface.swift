import TjuvkikCore

/// What the trigger opens: the board, or Spotlight. The app wires both the same way and talks to
/// the one `"view"` picks.
@MainActor
protocol GlanceSurface: AnyObject {
    var onShow: () -> Void { get set }
    var onHide: () -> Void { get set }
    /// Before a click inside is handled.
    var onMouseDown: () -> Void { get set }
    /// A click outside, or a Space or app switch.
    var onDismiss: () -> Void { get set }
    /// A click on a row with a `url` or `command`.
    var onRowAction: (Tile, RowAction) -> Void { get set }
    /// A keyboard command on the picked row, or its tile when the row is nil.
    var onCommand: (Tile, RowAction?, GlanceCommand.Kind) -> Void { get set }
    /// The `key`s of the picked row's actions, to take with ⌘ while it's picked.
    var onRowKeys: ([String]) -> Void { get set }
    /// A tile's right-click menu.
    var tileMenu: (Tile) -> TileMenu { get set }
    var closesOnClickOutside: Bool { get set }

    func show(sticky: Bool)
    /// After a pin: it stays open until dismissed.
    func stick()
    func hide()
    func handle(_ key: GlanceKey)
    /// Esc, before it closes: true when it was used, like closing the ⌘K list.
    func escape() -> Bool
}

extension GlanceController: GlanceSurface {}
