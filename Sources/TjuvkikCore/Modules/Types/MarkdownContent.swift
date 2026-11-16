import Foundation

/// Notes, runbooks, answers: `{ "markdown": "### On call this week\n**Anton** until Fri" }`, or a
/// file the panel points at. An s tile shows the heading and the first lines, m flows into two
/// columns, l the whole document, cut where the tile ends.
public struct MarkdownContent: Equatable, Sendable, Decodable {
    /// The text as written.
    public var markdown: String
    /// The text, parsed into blocks. Inline formatting stays in their text, for the view to draw.
    public var blocks: [MarkdownBlock]
    public var extras: PanelExtras

    public init(markdown: String, extras: PanelExtras = PanelExtras()) {
        self.markdown = markdown
        self.blocks = MarkdownParser.parse(markdown)
        self.extras = extras
    }

    private enum CodingKeys: String, CodingKey { case markdown }

    /// `markdown` is a string, or an array of lines.
    public init(from decoder: any Decoder) throws {
        let lines = try decoder.container(keyedBy: CodingKeys.self).decodeOneOrMany(String.self, forKey: .markdown)
        self.init(markdown: lines.joined(separator: "\n"), extras: try PanelExtras(from: decoder))
    }

    /// The level drawn as a title: the highest of the document's `#`, `##` and `###` headings.
    /// Deeper headings, and every `####` to `######`, are drawn as small section labels.
    public var titleLevel: Int? {
        MarkdownBlock.headingLevels(in: blocks).filter { $0 <= 3 }.min()
    }
}

/// A block of a Markdown document. Text keeps its inline Markdown (`**bold**`, `` `code` ``,
/// links), with soft line breaks joined into spaces and hard ones (two trailing spaces or a
/// backslash) kept as `\n`.
public indirect enum MarkdownBlock: Equatable, Sendable {
    /// `#` to `######`.
    case heading(level: Int, text: String)
    case paragraph(String)
    /// The items of one list, nested ones with a higher depth.
    case list([MarkdownListItem])
    /// A fenced block: ```` ```sh ````. `language` is the first word after the fence.
    case code(language: String?, text: String)
    /// `> `: drawn in the warning tone.
    case quote([MarkdownBlock])
    /// `---`, `***` or `___`.
    case rule

    static func headingLevels(in blocks: [MarkdownBlock]) -> [Int] {
        blocks.flatMap { block -> [Int] in
            switch block {
            case .heading(let level, _): [level]
            case .quote(let inner): headingLevels(in: inner)
            case .paragraph, .list, .code, .rule: []
            }
        }
    }
}

public struct MarkdownListItem: Equatable, Sendable {
    public enum Marker: Equatable, Sendable {
        case bullet
        /// The item's number, counted on from the first item at its depth.
        case number(Int)
    }

    public var marker: Marker
    /// 0 for a top-level item, 1 for one nested under it, up to 3.
    public var depth: Int
    /// `- [x]` is true, `- [ ]` false, nil when it isn't a task.
    public var checked: Bool?
    public var text: String

    public init(marker: Marker = .bullet, depth: Int = 0, checked: Bool? = nil, text: String) {
        self.marker = marker
        self.depth = depth
        self.checked = checked
        self.text = text
    }
}

/// A CommonMark subset, block by block: ATX headings, paragraphs, bullet and numbered lists
/// (nested by indentation), task lists, fenced code, blockquotes and thematic breaks. Not
/// supported, so read as text: setext headings, indented code, HTML, tables and link reference
/// definitions.
public enum MarkdownParser {
    /// Nested lists deeper than this are drawn at this depth.
    public static let maximumDepth = 3

    public static func parse(_ text: String) -> [MarkdownBlock] {
        let normalized = text.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map { expandingLeadingTabs(String($0)) }
        return blocks(lines)
    }

    static func blocks(_ lines: [String]) -> [MarkdownBlock] {
        var parser = BlockParser(lines: lines)
        return parser.run()
    }

    /// Joins a paragraph's lines: a soft break becomes a space, a hard one (two trailing spaces,
    /// or a trailing backslash) a newline.
    static func join(_ lines: [String]) -> String {
        var text = ""
        for (index, line) in lines.enumerated() {
            if index == lines.count - 1 {
                text += line.trimmingTrailingWhitespace
            } else if line.hasSuffix("\\") {
                text += String(line.dropLast()) + "\n"
            } else if line.hasSuffix("  ") {
                text += line.trimmingTrailingWhitespace + "\n"
            } else {
                text += line.trimmingTrailingWhitespace + " "
            }
        }
        return text
    }

    /// A tab in the indentation counts as four spaces.
    private static func expandingLeadingTabs(_ line: String) -> String {
        guard line.contains("\t") else { return line }
        var prefix = ""
        var rest = Substring(line)
        while let first = rest.first, first == " " || first == "\t" {
            prefix += first == "\t" ? String(repeating: " ", count: 4 - prefix.count % 4) : " "
            rest = rest.dropFirst()
        }
        return prefix + rest
    }
}

/// What one line starts, before knowing what's around it.
enum MarkdownLine: Equatable {
    case blank
    case heading(level: Int, text: String)
    case rule
    case fence(Fence)
    /// After `>` and one optional space.
    case quote(String)
    /// `contentIndent` is the column the item's text starts at.
    case item(indent: Int, ordered: Int?, text: String, contentIndent: Int)
    /// Without its indentation, which is in `indent`.
    case text(indent: Int, String)

    struct Fence: Equatable {
        var character: Character
        var length: Int
        var indent: Int
        var info: String
    }

    init(_ line: String) {
        let indent = line.prefix { $0 == " " }.count
        let rest = String(line.dropFirst(indent))
        if rest.allSatisfy(\.isWhitespace) {
            self = .blank
            return
        }
        if indent <= 3 {
            if let fence = Self.fence(rest, indent: indent) {
                self = .fence(fence)
                return
            }
            if let heading = Self.heading(rest) {
                self = heading
                return
            }
            if Self.isRule(rest) {
                self = .rule
                return
            }
            if rest.hasPrefix(">") {
                let quoted = rest.dropFirst()
                self = .quote(String(quoted.hasPrefix(" ") ? quoted.dropFirst() : quoted))
                return
            }
        }
        if let item = Self.item(rest, indent: indent) {
            self = item
            return
        }
        self = .text(indent: indent, rest)
    }

    private static func fence(_ rest: String, indent: Int) -> Fence? {
        guard let first = rest.first, first == "`" || first == "~" else { return nil }
        let length = rest.prefix { $0 == first }.count
        guard length >= 3 else { return nil }
        let info = rest.dropFirst(length).trimmingCharacters(in: .whitespaces)
        // A backtick fence's info can't hold a backtick, so ```` ```code``` ```` stays inline code.
        if first == "`" && info.contains("`") { return nil }
        return Fence(character: first, length: length, indent: indent, info: info)
    }

    /// Whether this line closes `fence`: the same character, at least as many, and nothing else.
    static func closes(_ line: String, _ fence: Fence) -> Bool {
        let indent = line.prefix { $0 == " " }.count
        guard indent <= 3 else { return false }
        let rest = line.dropFirst(indent).trimmingCharacters(in: .whitespaces)
        return rest.count >= fence.length && rest.allSatisfy { $0 == fence.character }
    }

    private static func heading(_ rest: String) -> MarkdownLine? {
        let level = rest.prefix { $0 == "#" }.count
        guard (1...6).contains(level) else { return nil }
        let after = rest.dropFirst(level)
        guard after.isEmpty || after.first == " " || after.first == "\t" else { return nil }
        var text = after.trimmingCharacters(in: .whitespaces)
        // A closing run of #s goes, when it's all there is or follows a space.
        let closing = text.reversed().prefix { $0 == "#" }.count
        if closing > 0 {
            let before = text.dropLast(closing)
            if before.isEmpty {
                text = ""
            } else if before.last == " " || before.last == "\t" {
                text = before.trimmingCharacters(in: .whitespaces)
            }
        }
        return .heading(level: level, text: text)
    }

    private static func isRule(_ rest: String) -> Bool {
        let marks = rest.filter { $0 != " " && $0 != "\t" }
        guard let first = marks.first, "-*_".contains(first), marks.count >= 3 else { return false }
        return marks.allSatisfy { $0 == first }
    }

    private static func item(_ rest: String, indent: Int) -> MarkdownLine? {
        var ordered: Int?
        var markerLength: Int
        if let first = rest.first, "-*+".contains(first) {
            markerLength = 1
        } else {
            let digits = rest.prefix { $0.isASCII && $0.isNumber }
            guard (1...9).contains(digits.count), let number = Int(digits) else { return nil }
            let delimiter = rest.dropFirst(digits.count).first
            guard delimiter == "." || delimiter == ")" else { return nil }
            ordered = number
            markerLength = digits.count + 1
        }
        let after = rest.dropFirst(markerLength)
        guard after.isEmpty || after.first == " " || after.first == "\t" else { return nil }
        let spaces = max(after.prefix { $0 == " " || $0 == "\t" }.count, 1)
        let text = String(after.drop { $0 == " " || $0 == "\t" })
        return .item(indent: indent, ordered: ordered, text: text, contentIndent: indent + markerLength + spaces)
    }
}

private struct BlockParser {
    let lines: [String]
    var index = 0
    var blocks: [MarkdownBlock] = []
    var paragraph: [String] = []

    init(lines: [String]) {
        self.lines = lines
    }

    mutating func run() -> [MarkdownBlock] {
        while index < lines.count {
            switch MarkdownLine(lines[index]) {
            case .blank:
                flushParagraph()
                index += 1
            case .fence(let fence):
                flushParagraph()
                code(fence)
            case .heading(let level, let text):
                flushParagraph()
                blocks.append(.heading(level: level, text: text))
                index += 1
            case .rule:
                flushParagraph()
                blocks.append(.rule)
                index += 1
            case .quote:
                flushParagraph()
                quote()
            case .item:
                flushParagraph()
                list()
            case .text(_, let text):
                paragraph.append(text)
                index += 1
            }
        }
        flushParagraph()
        return blocks
    }

    private mutating func flushParagraph() {
        guard !paragraph.isEmpty else { return }
        blocks.append(.paragraph(MarkdownParser.join(paragraph)))
        paragraph = []
    }

    /// Up to the closing fence, or the end when there's none.
    private mutating func code(_ fence: MarkdownLine.Fence) {
        index += 1
        var code: [String] = []
        while index < lines.count {
            let line = lines[index]
            index += 1
            if MarkdownLine.closes(line, fence) { break }
            let indent = min(line.prefix { $0 == " " }.count, fence.indent)
            code.append(String(line.dropFirst(indent)))
        }
        let language = fence.info.split(separator: " ").first.map(String.init)
        blocks.append(.code(language: language, text: code.joined(separator: "\n")))
    }

    /// Lines starting with `>`, and lines that continue a quoted paragraph without one.
    private mutating func quote() {
        var quoted: [String] = []
        var inParagraph = false
        while index < lines.count {
            let line = MarkdownLine(lines[index])
            if case .quote(let text) = line {
                quoted.append(text)
                if case .text = MarkdownLine(text) { inParagraph = true } else { inParagraph = false }
            } else if case .text(_, let text) = line, inParagraph {
                quoted.append(text)
            } else {
                break
            }
            index += 1
        }
        blocks.append(.quote(MarkdownParser.blocks(quoted)))
    }

    /// Items, nested by indentation: an item indented at least two columns past the one above it
    /// is nested under it. Blank lines between items keep the list going.
    private mutating func list() {
        var items: [(item: MarkdownListItem, lines: [[String]])] = []
        var indents: [Int] = []
        var numbers: [Int?] = []
        var contentIndent = 0
        while index < lines.count {
            switch MarkdownLine(lines[index]) {
            case .item(let indent, let ordered, let text, let itemContentIndent):
                if let last = indents.last, indent >= last + 2, indents.count <= MarkdownParser.maximumDepth {
                    indents.append(indent)
                    numbers.append(nil)
                } else {
                    while indents.count > 1, let last = indents.last, indent < last {
                        indents.removeLast()
                        numbers.removeLast()
                    }
                    if indents.isEmpty {
                        indents.append(indent)
                        numbers.append(nil)
                    }
                }
                let depth = indents.count - 1
                var marker = MarkdownListItem.Marker.bullet
                if let ordered {
                    let number = numbers[depth].map { $0 + 1 } ?? ordered
                    numbers[depth] = number
                    marker = .number(number)
                } else {
                    numbers[depth] = nil
                }
                let (checked, rest) = Self.task(text)
                items.append((MarkdownListItem(marker: marker, depth: depth, checked: checked, text: ""), [[rest]]))
                contentIndent = itemContentIndent
                index += 1
            case .text(_, let text) where !items.isEmpty:
                // A line right under an item continues its text.
                let last = items.count - 1
                let lastParagraph = items[last].lines.count - 1
                items[last].lines[lastParagraph].append(text)
                index += 1
            case .blank:
                // Goes on with the next item, or a paragraph indented under the last one.
                var next = index + 1
                while next < lines.count, MarkdownLine(lines[next]) == .blank { next += 1 }
                guard next < lines.count else {
                    index = next
                    return finish(items)
                }
                switch MarkdownLine(lines[next]) {
                case .item:
                    index = next
                case .text(let indent, let text) where indent >= min(contentIndent, 2) && !items.isEmpty:
                    items[items.count - 1].lines.append([text])
                    index = next + 1
                default:
                    index = next
                    return finish(items)
                }
            default:
                return finish(items)
            }
        }
        finish(items)
    }

    private mutating func finish(_ items: [(item: MarkdownListItem, lines: [[String]])]) {
        guard !items.isEmpty else { return }
        blocks.append(.list(items.map { entry in
            var item = entry.item
            item.text = entry.lines.map(MarkdownParser.join).joined(separator: "\n")
            return item
        }))
    }

    /// `[ ] Buy milk` is an open task, `[x] Buy milk` a done one.
    private static func task(_ text: String) -> (Bool?, String) {
        for (box, checked) in [("[ ]", false), ("[x]", true), ("[X]", true)] where text.hasPrefix(box) {
            let rest = text.dropFirst(box.count)
            if rest.isEmpty || rest.first == " " {
                return (checked, String(rest.drop { $0 == " " }))
            }
        }
        return (nil, text)
    }
}

/// Places a document's blocks in a tile's columns: whole blocks only, and never a heading at the
/// bottom of a column without what it heads. Two columns are balanced, as CSS columns are, when
/// everything fits; otherwise each column fills in turn and what's left is cut.
public enum MarkdownFlow {
    public struct Piece: Equatable, Sendable {
        public var height: Double
        /// Space above it, unless it starts a column.
        public var spacing: Double
        /// A heading: kept with the piece after it.
        public var keepWithNext: Bool

        public init(height: Double, spacing: Double = 0, keepWithNext: Bool = false) {
            self.height = height
            self.spacing = spacing
            self.keepWithNext = keepWithNext
        }
    }

    public struct Slot: Equatable, Sendable {
        public var column: Int
        public var y: Double
        public var height: Double

        public init(column: Int, y: Double, height: Double) {
            self.column = column
            self.y = y
            self.height = height
        }
    }

    /// Where each piece goes, or nil when it's cut. A piece taller than a whole column starts
    /// one and is cut to its height, so a long first paragraph still shows.
    public static func place(_ pieces: [Piece], columns: Int, height: Double) -> [Slot?] {
        if columns == 2, let split = balancedSplit(pieces, height: height) {
            return stack(pieces[..<split], column: 0) + stack(pieces[split...], column: 1)
        }
        return fill(pieces, columns: max(columns, 1), height: height)
    }

    /// The split into two columns with the shorter taller column, when that fits.
    static func balancedSplit(_ pieces: [Piece], height: Double) -> Int? {
        guard pieces.count > 1 else { return nil }
        var best: (split: Int, height: Double)?
        for split in 1..<pieces.count where !pieces[split - 1].keepWithNext {
            let taller = max(columnHeight(pieces[..<split]), columnHeight(pieces[split...]))
            if let current = best, taller >= current.height - 0.001 { continue }
            best = (split, taller)
        }
        guard let best, best.height <= height + 0.5 else { return nil }
        return best.split
    }

    static func columnHeight(_ pieces: ArraySlice<Piece>) -> Double {
        pieces.enumerated().reduce(0.0) { $0 + $1.element.height + ($1.offset == 0 ? 0 : $1.element.spacing) }
    }

    private static func stack(_ pieces: ArraySlice<Piece>, column: Int) -> [Slot?] {
        var y = 0.0
        return pieces.enumerated().map { offset, piece in
            if offset > 0 { y += piece.spacing }
            defer { y += piece.height }
            return Slot(column: column, y: y, height: piece.height)
        }
    }

    private static func fill(_ pieces: [Piece], columns: Int, height: Double) -> [Slot?] {
        var slots = [Slot?](repeating: nil, count: pieces.count)
        var column = 0
        var y = 0.0
        var count = 0
        var index = 0
        while index < pieces.count, column < columns {
            let piece = pieces[index]
            let top = count == 0 ? 0 : piece.spacing
            if y + top + piece.height <= height + 0.5 {
                slots[index] = Slot(column: column, y: y + top, height: piece.height)
                y += top + piece.height
                count += 1
                index += 1
                continue
            }
            if count == 0 {
                slots[index] = Slot(column: column, y: 0, height: height)
                index += 1
            } else if count > 1, pieces[index - 1].keepWithNext {
                index -= 1
                slots[index] = nil
            }
            column += 1
            y = 0
            count = 0
        }
        return slots
    }
}

private extension StringProtocol {
    var trimmingTrailingWhitespace: String {
        var text = String(self)
        while let last = text.last, last == " " || last == "\t" { text.removeLast() }
        return text
    }
}
