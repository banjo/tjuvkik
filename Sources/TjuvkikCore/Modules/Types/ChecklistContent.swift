import Foundation

/// Steps and how far along they are: `{ "items": [{ "title": "Freeze main", "state": "done" }] }`.
/// Read-only: the script owns the list. An s tile shows the count, a bar and the next step, m the
/// items, l sections and notes with done items folded.
public struct ChecklistContent: Equatable, Sendable, Decodable {
    public enum State: String, Equatable, Sendable, CaseIterable, Decodable {
        case todo, doing, done, blocked, skipped

        /// Unknown states read as todo, so a script written for a later version still renders.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let done = try? container.decode(Bool.self) {
                self = done ? .done : .todo
                return
            }
            let text = try container.decode(String.self).trimmingCharacters(in: .whitespaces).lowercased()
            self = State(rawValue: text) ?? .todo
        }
    }

    public struct Task: Equatable, Sendable {
        public var title: String
        public var state: State
        /// Who's on it, shown at the end of the line.
        public var who: String?
        /// A line under the title, in the error tone when blocked.
        public var note: String?

        public init(title: String, state: State = .todo, who: String? = nil, note: String? = nil) {
            self.title = title
            self.state = state
            self.who = who
            self.note = note
        }
    }

    /// A heading, or a step.
    public enum Item: Equatable, Sendable, Decodable {
        case section(String)
        case task(Task)

        private enum CodingKeys: String, CodingKey { case section, title, state, who, note }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if !container.contains(.title), let section = try container.decodeTextIfPresent(forKey: .section) {
                self = .section(section)
                return
            }
            self = .task(Task(
                title: try container.decodeText(forKey: .title),
                state: try container.decodeIfPresent(State.self, forKey: .state) ?? .todo,
                who: try container.decodeTextIfPresent(forKey: .who),
                note: try container.decodeTextIfPresent(forKey: .note)
            ))
        }

        /// The step, or nil for a section.
        public var asTask: Task? {
            if case .task(let task) = self { return task }
            return nil
        }
    }

    public var items: [Item]
    /// Hides done and skipped steps in an l tile, behind one "✓ 3 done" line.
    public var foldDone: Bool
    /// Next to the count, like "steps · release Thu 14:00".
    public var caption: String?
    public var extras: PanelExtras

    public init(items: [Item], foldDone: Bool = false, caption: String? = nil, extras: PanelExtras = PanelExtras()) {
        self.items = items
        self.foldDone = foldDone
        self.caption = caption
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case items, foldDone, caption }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([Item].self, forKey: .items)
        foldDone = try container.decodeIfPresent(Bool.self, forKey: .foldDone) ?? false
        caption = try container.decodeTextIfPresent(forKey: .caption)
        extras = try PanelExtras(from: decoder)
    }

    // MARK: Progress

    public var tasks: [Task] { items.compactMap(\.asTask) }

    /// Done steps.
    public var done: Int { tasks.count(where: { $0.state == .done }) }
    /// Steps in progress.
    public var doing: Int { tasks.count(where: { $0.state == .doing }) }
    /// Steps that count: all but skipped ones.
    public var total: Int { tasks.count(where: { $0.state != .skipped }) }
    /// Skipped steps, which count as neither done nor left.
    public var skipped: Int { tasks.count(where: { $0.state == .skipped }) }

    /// "2/8"
    public var count: String { "\(done)/\(total)" }

    /// Done steps out of all, 0 to 1. 0 for an empty list.
    public var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }
    /// Steps in progress out of all, 0 to 1: the bar's second part.
    public var doingProgress: Double { total == 0 ? 0 : Double(doing) / Double(total) }

    /// The first step in progress, else the first one left to do. Nil when nothing is.
    public var next: Task? {
        tasks.first { $0.state == .doing } ?? tasks.first { $0.state == .todo }
    }

    /// Every step is done or skipped, and there is at least one.
    public var isComplete: Bool { !tasks.isEmpty && tasks.allSatisfy { $0.state == .done || $0.state == .skipped } }

    // MARK: Folding

    /// What an l tile lists: with `foldDone`, done and skipped steps go, and so do sections left
    /// with no steps under them.
    public var visibleItems: [Item] {
        guard foldDone else { return items }
        let shown = items.filter { !Self.folds($0) }
        return shown.indices.compactMap { index -> Item? in
            guard case .section = shown[index] else { return shown[index] }
            // A section stays when a step follows it before the next section.
            let next = shown.index(after: index)
            guard next < shown.endIndex, shown[next].asTask != nil else { return nil }
            return shown[index]
        }
    }

    /// The line that stands for the folded steps, like "✓ 3 done" or "✓ 3 done · 1 skipped".
    /// Nil without `foldDone`, or when nothing is folded.
    public var foldedLine: String? {
        guard foldDone, done + skipped > 0 else { return nil }
        let parts = [done > 0 ? "\(done) done" : nil, skipped > 0 ? "\(skipped) skipped" : nil].compactMap { $0 }
        return "✓ " + parts.joined(separator: " · ")
    }

    private static func folds(_ item: Item) -> Bool {
        guard let task = item.asTask else { return false }
        return task.state == .done || task.state == .skipped
    }

    // MARK: Columns

    /// How many columns an m tile needs for `count` steps when `rowsThatFit` fit in one: two
    /// when one isn't enough.
    public static func columns(for count: Int, rowsThatFit: Int) -> Int {
        count > max(rowsThatFit, 1) ? 2 : 1
    }
}
