import Foundation

/// The changes the settings window makes to `config.jsonc`, each as small an edit to the text as
/// it can be. A setting at its default is removed rather than written.
public struct ConfigEditor {
    public private(set) var document: JSONCDocument

    public init(_ text: String) throws(JSONCDocument.ParseError) {
        document = try JSONCDocument(text)
    }

    public var text: String { document.text }

    // MARK: General

    public mutating func setTrigger(_ trigger: Trigger) throws(JSONCDocument.ParseError) {
        let defaultMode: Trigger.Mode
        switch trigger.input {
        case .key(let key):
            try update(["trigger", "key"], key == .fn ? nil : .string(key.rawValue))
            try document.remove(at: ["trigger", "shortcut"])
            defaultMode = .hold
        case .shortcut(let shortcut):
            try document.set(.string(shortcut.description), at: ["trigger", "shortcut"])
            try document.remove(at: ["trigger", "key"])
            defaultMode = .toggle
        }
        try update(["trigger", "mode"], trigger.mode == defaultMode ? nil : .string(trigger.mode.rawValue))
        let hold = trigger.mode == .hold && trigger.holdMilliseconds != 250
        try update(["trigger", "holdMs"], hold ? .number(Double(trigger.holdMilliseconds)) : nil)
        let doubleTap = trigger.mode == .doubleTap && trigger.doubleTapMilliseconds != 300
        try update(["trigger", "doubleTapMs"], doubleTap ? .number(Double(trigger.doubleTapMilliseconds)) : nil)
        try update(["trigger", "closeOnClickOutside"], trigger.closeOnClickOutside ? nil : .bool(false))
        try removeIfEmpty(["trigger"])
    }

    public mutating func setLaunchAtLogin(_ on: Bool) throws(JSONCDocument.ParseError) {
        try update(["launchAtLogin"], on ? nil : .bool(false))
    }

    public mutating func setPause(whenLocked: Bool, onLowPower: Bool) throws(JSONCDocument.ParseError) {
        try update(["pause", "whenLocked"], whenLocked ? nil : .bool(false))
        try update(["pause", "onLowPower"], onLowPower ? nil : .bool(false))
        try removeIfEmpty(["pause"])
    }

    public mutating func setNotifications(enabled: Bool, sound: Bool, quietHours: String?, whileOpen: Bool) throws(JSONCDocument.ParseError) {
        try update(["notifications", "enabled"], enabled ? nil : .bool(false))
        try update(["notifications", "sound"], sound ? nil : .bool(false))
        try update(["notifications", "quietHours"], quietHours.map { .string($0) })
        try update(["notifications", "whileOpen"], whileOpen ? .bool(true) : nil)
        try removeIfEmpty(["notifications"])
    }

    // MARK: Board

    public mutating func setGrid(_ grid: BoardGrid) throws(JSONCDocument.ParseError) {
        try update(["grid"], grid == .standard ? nil : .string(grid.description))
    }

    public mutating func setZoom(_ zoom: Config.Zoom) throws(JSONCDocument.ParseError) {
        switch zoom {
        case .auto: try update(["zoom"], nil)
        case .fixed(let value): try update(["zoom"], .number(value))
        }
    }

    /// `true` for the default amount.
    public mutating func setDim(_ dim: Double) throws(JSONCDocument.ParseError) {
        try update(["dim"], dim == 0 ? nil : dim == Config.defaultDim ? .bool(true) : .number(dim))
    }

    public mutating func setFocusOnOpen(_ focus: Config.FocusOnOpen) throws(JSONCDocument.ParseError) {
        try update(["focusOnOpen"], focus == .urgent ? nil : .string(focus.rawValue))
    }

    // MARK: Theme

    public mutating func setTheme(_ name: String) throws(JSONCDocument.ParseError) {
        try update(["theme"], name == "dark-glass" ? nil : .string(name))
    }

    /// One name when both are the same.
    public mutating func setTheme(light: String, dark: String) throws(JSONCDocument.ParseError) {
        guard light != dark else { return try setTheme(light) }
        if document.keys(at: ["theme"]) != nil {
            try document.set(.string(light), at: ["theme", "light"])
            try document.set(.string(dark), at: ["theme", "dark"])
        } else {
            try document.set(.object([("light", .string(light)), ("dark", .string(dark))]), at: ["theme"])
        }
    }

    // MARK: Tiles

    /// What the file says about the tiles, in order, for the Board list.
    public func entries() -> [Entry] {
        (0..<document.count(at: ["panels"])).compactMap { index in
            guard let panel = document.value(String.self, at: ["panels", .index(index), "panel"]) else { return nil }
            return Entry(index: index, panel: panel, id: document.value(String.self, at: ["panels", .index(index), "id"]))
        }
    }

    /// Appends the panel, with an id like `ci-2` when its name is taken.
    public mutating func addTile(panel: String) throws(JSONCDocument.ParseError) {
        let taken = Set(entries().map(\.resolvedID))
        var members: [(String, JSONCDocument.Value)] = [("panel", .string(panel))]
        if taken.contains(panel) {
            var number = 2
            while taken.contains("\(panel)-\(number)") { number += 1 }
            members.append(("id", .string("\(panel)-\(number)")))
        }
        try document.insert(.object(members), into: ["panels"], at: document.count(at: ["panels"]))
    }

    /// `index` is the tile's place in `panels`. Its id leaves `menuBar` too.
    public mutating func removeTile(at index: Int) throws(JSONCDocument.ParseError) {
        let id = entry(at: index)?.resolvedID
        try document.remove(at: ["panels", .index(index)])
        if let id { try setInMenuBar(id, false) }
    }

    /// `to` is where the tile ends up.
    public mutating func moveTile(from: Int, to: Int) throws(JSONCDocument.ParseError) {
        try document.move(in: ["panels"], from: from, to: to)
    }

    /// Nil removes the key.
    public mutating func setTile(_ index: Int, _ key: TileKey, _ value: JSONCDocument.Value?) throws(JSONCDocument.ParseError) {
        try update(["panels", .index(index), .name(key.rawValue)], value)
    }

    /// Nil, or the panel's name, removes `id`. `menuBar` follows.
    public mutating func renameTile(_ index: Int, to id: String?) throws(JSONCDocument.ParseError) {
        guard let entry = entry(at: index) else { return }
        let new = id ?? entry.panel
        try update(["panels", .index(index), "id"], new == entry.panel ? nil : .string(new))
        let shown = menuBar()
        guard let position = shown.values.firstIndex(of: entry.resolvedID), new != entry.resolvedID else { return }
        try document.set(.string(new), at: shown.isArray ? ["menuBar", .index(position)] : ["menuBar"])
    }

    /// Nil removes the option, and `options` when it's left empty.
    public mutating func setOption(_ index: Int, _ name: String, _ value: JSONCDocument.Value?) throws(JSONCDocument.ParseError) {
        try update(["panels", .index(index), "options", .name(name)], value)
        try removeIfEmpty(["panels", .index(index), "options"])
    }

    /// One id is written as a string, several as an array in the tiles' order, none removes `menuBar`.
    public mutating func setInMenuBar(_ id: String, _ shown: Bool) throws(JSONCDocument.ParseError) {
        let current = menuBar()
        var values = current.values
        if shown {
            guard !values.contains(id) else { return }
            let order = entries().map(\.resolvedID)
            let rank = { (id: String) in order.firstIndex(of: id) ?? order.count }
            let position = values.firstIndex { rank($0) > rank(id) } ?? values.count
            values.insert(id, at: position)
            if current.isArray, values.count > 1 {
                try document.insert(.string(id), into: ["menuBar"], at: position)
                return
            }
        } else {
            guard let position = values.firstIndex(of: id) else { return }
            values.remove(at: position)
            if current.isArray, values.count > 1 {
                try document.remove(at: ["menuBar", .index(position)])
                return
            }
        }
        switch values.count {
        case 0: try document.remove(at: ["menuBar"])
        case 1: try document.set(.string(values[0]), at: ["menuBar"])
        default: try document.set(.array(values.map { .string($0) }), at: ["menuBar"])
        }
    }

    // MARK: Helpers

    private func entry(at index: Int) -> Entry? {
        entries().first { $0.index == index }
    }

    /// `menuBar` as written: a string, or an array.
    private func menuBar() -> (values: [String], isArray: Bool) {
        if let values = document.value([String].self, at: ["menuBar"]) { return (values, true) }
        return (document.value(String.self, at: ["menuBar"]).map { [$0] } ?? [], false)
    }

    /// Sets the value, or removes it when it's nil.
    private mutating func update(_ path: [JSONCDocument.Key], _ value: JSONCDocument.Value?) throws(JSONCDocument.ParseError) {
        if let value { try document.set(value, at: path) } else { try document.remove(at: path) }
    }

    private mutating func removeIfEmpty(_ path: [JSONCDocument.Key]) throws(JSONCDocument.ParseError) {
        if document.keys(at: path)?.isEmpty == true { try document.remove(at: path) }
    }
}

extension ConfigEditor {
    public struct Entry: Equatable, Sendable {
        /// Its place in `panels`.
        public var index: Int
        public var panel: String
        /// `id` as written; nil when it's the panel name.
        public var id: String?
        public var resolvedID: String { id ?? panel }

        public init(index: Int, panel: String, id: String? = nil) {
            self.index = index
            self.panel = panel
            self.id = id
        }
    }

    public enum TileKey: String, Sendable { case size, title, show, focus, background, notify }
}
