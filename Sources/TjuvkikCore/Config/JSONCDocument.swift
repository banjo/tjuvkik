import Foundation

/// A JSONC file that can be changed one value at a time, keeping everything else as written.
///
/// It reads what `JSONDecoder` with `allowsJSON5` reads in Tjuvkik's files: comments, trailing
/// commas, single-quoted strings, unquoted keys. Each edit replaces, adds or removes the text of
/// one value, and the text is parsed again after it.
public struct JSONCDocument: Equatable, Sendable {
    public enum Key: Equatable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
        case name(String)
        case index(Int)

        public init(stringLiteral value: String) { self = .name(value) }
        public init(integerLiteral value: Int) { self = .index(value) }
    }

    /// A value to write.
    public indirect enum Value: Equatable, Sendable {
        case string(String), number(Double), bool(Bool), null
        case array([Value])
        /// Keys in this order.
        case object([(String, Value)])

        public static func == (lhs: Value, rhs: Value) -> Bool {
            switch (lhs, rhs) {
            case (.string(let a), .string(let b)): a == b
            case (.number(let a), .number(let b)): a == b
            case (.bool(let a), .bool(let b)): a == b
            case (.null, .null): true
            case (.array(let a), .array(let b)): a == b
            case (.object(let a), .object(let b)): a.map(\.0) == b.map(\.0) && a.map(\.1) == b.map(\.1)
            default: false
            }
        }
    }

    public struct ParseError: Error, Equatable, Sendable {
        public var line: Int
        public var column: Int
        public var message: String

        public init(line: Int, column: Int, message: String) {
            self.line = line
            self.column = column
            self.message = message
        }
    }

    public private(set) var text: String
    private var bytes: [UInt8]
    private var root: Node

    public init(_ text: String) throws(ParseError) {
        self.text = text
        bytes = Array(text.utf8)
        var parser = Parser(bytes: bytes)
        root = try parser.parseDocument()
    }

    public static func == (lhs: JSONCDocument, rhs: JSONCDocument) -> Bool { lhs.text == rhs.text }

    // MARK: Reading

    /// The value at `path` decoded as `T`, or nil if it's not there or not a `T`.
    public func value<T: Decodable>(_ type: T.Type, at path: [Key]) -> T? {
        guard let node = node(at: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try? decoder.decode(T.self, from: Data(bytes[node.range]))
    }

    /// How many items the array at `path` has; 0 if it's not an array.
    public func count(at path: [Key]) -> Int {
        guard let node = node(at: path), node.kind == .array else { return 0 }
        return node.items.count
    }

    /// The keys of the object at `path`, in order; nil if it's not an object.
    func keys(at path: [Key]) -> [String]? {
        guard let node = node(at: path), node.kind == .object else { return nil }
        return node.members.map(\.key)
    }

    // MARK: Editing

    /// Replaces the value at `path`, or adds the key to its object. Creates missing objects
    /// on the way. An index must exist.
    public mutating func set(_ value: Value, at path: [Key]) throws(ParseError) {
        guard let last = path.last else {
            try apply([(root.range, Self.render(value))])
            return
        }
        let parentPath = Array(path.dropLast())
        guard let parent = node(at: parentPath) else {
            guard case .name(let name) = last else { throw missingItem(last, in: root) }
            try set(.object([(name, value)]), at: parentPath)
            return
        }
        switch (last, parent.kind) {
        case (.name(let name), .object):
            if let member = parent.members.last(where: { $0.key == name }) {
                try apply([(member.value.range, Self.render(value))])
            } else {
                try insert(raw: "\(Self.render(.string(name))): \(Self.render(value))", comment: "", into: parent, at: parent.members.count)
            }
        case (.name(let name), _):
            try apply([(parent.range, Self.render(.object([(name, value)])))])
        case (.index(let index), .array) where parent.items.indices.contains(index):
            try apply([(parent.items[index].range, Self.render(value))])
        case (.index, _):
            throw missingItem(last, in: parent)
        }
    }

    /// Removes a key or an array item, with its line when it has one to itself. Nothing if missing.
    public mutating func remove(at path: [Key]) throws(ParseError) {
        guard let (parent, index) = child(at: path) else { return }
        try apply(removal(of: index, in: parent))
    }

    /// Adds an item to the array at `path`, at `index` (`count` appends). Creates the array if missing.
    public mutating func insert(_ value: Value, into path: [Key], at index: Int) throws(ParseError) {
        guard let array = node(at: path), array.kind == .array else {
            try set(.array([value]), at: path)
            return
        }
        try insert(raw: Self.render(value), comment: "", into: array, at: min(max(index, 0), array.items.count))
    }

    /// Moves an array item, comments on its line included.
    public mutating func move(in path: [Key], from: Int, to: Int) throws(ParseError) {
        guard let array = node(at: path), array.kind == .array, array.items.indices.contains(from), from != to else { return }
        let item = array.items[from]
        let value = String(decoding: bytes[item.range], as: UTF8.self)
        var comment = ""
        if isAlone(item.range, in: array) {
            let after = commaAfter(item.range.upperBound, in: array).map { $0 + 1 } ?? item.range.upperBound
            comment = String(decoding: bytes[after..<lineEnd(after)], as: UTF8.self)
                .trimmingCharacters(in: .whitespaces)
            if !comment.isEmpty { comment = " " + comment }
        }
        try apply(removal(of: from, in: array))
        guard let moved = node(at: path) else { return }
        try insert(raw: value, comment: comment, into: moved, at: min(max(to, 0), moved.items.count))
    }

    // MARK: Edits on the text

    /// Replaces ranges of the text, which must not overlap, and parses it again.
    private mutating func apply(_ edits: [(Range<Int>, String)]) throws(ParseError) {
        var new = bytes
        for (range, replacement) in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
            new.replaceSubrange(range, with: Array(replacement.utf8))
        }
        var parser = Parser(bytes: new)
        root = try parser.parseDocument()
        bytes = new
        text = String(decoding: new, as: UTF8.self)
    }

    /// Adds `raw`, a member or an item as text, to a container. `comment` goes at the end of its
    /// line, after its comma.
    private mutating func insert(raw: String, comment: String, into container: Node, at index: Int) throws(ParseError) {
        let children = container.childRanges
        let open = container.range.lowerBound, close = container.range.upperBound - 1
        let multiLine = line(of: open) != line(of: close)

        if index < children.count {
            let start = children[index].lowerBound
            if isFirstOnLine(start) {
                let indent = indentation(of: start)
                try apply([(start..<start, raw + "," + comment + "\n" + indent)])
            } else {
                try apply([(start..<start, raw + ", ")])
            }
            return
        }

        guard let last = children.last else {
            let inner = (open + 1)..<close
            if !multiLine, bytes[inner].allSatisfy(Self.isSpace), comment.isEmpty {
                try apply([(inner, " \(raw) ")])
            } else {
                var end = close
                while end > open + 1, Self.isWhitespace(bytes[end - 1]) { end -= 1 }
                let indent = indentation(of: open)
                try apply([(end..<close, "\n" + indent + "  " + raw + comment + "\n" + indent)])
            }
            return
        }

        let comma = commaAfter(last.upperBound, in: container)
        guard multiLine else {
            try apply([(last.upperBound..<last.upperBound, ", " + raw)])
            return
        }
        let indent = indentation(of: last.lowerBound)
        let after = comma.map { $0 + 1 } ?? last.upperBound
        // After a comment on the last member's line, so the comment stays on that line.
        let at = restOfLineIsComment(after) ? lineEnd(after) : after
        let added = "\n" + indent + raw + (comma != nil ? "," : "") + comment
        if comma == nil, at == last.upperBound {
            try apply([(at..<at, "," + added)])
        } else if comma == nil {
            try apply([(last.upperBound..<last.upperBound, ","), (at..<at, added)])
        } else {
            try apply([(at..<at, added)])
        }
    }

    /// The text to delete to remove a container's child.
    private func removal(of index: Int, in container: Node) -> [(Range<Int>, String)] {
        let children = container.childRanges
        let range = children[index]
        let comma = commaAfter(range.upperBound, in: container)
        if isAlone(range, in: container) {
            let after = comma.map { $0 + 1 } ?? range.upperBound
            var end = lineEnd(after)
            if end < bytes.count, bytes[end] == 0x0D { end += 1 }
            if end < bytes.count, bytes[end] == 0x0A { end += 1 }
            var edits = [(lineStart(range.lowerBound)..<end, "")]
            // The last one goes: the one before it loses the comma it had for it.
            if comma == nil, index == children.count - 1, index > 0,
               let previous = commaAfter(children[index - 1].upperBound, in: container) {
                edits.append((previous..<(previous + 1), ""))
            }
            return edits
        }
        if let comma {
            var end = comma + 1
            while end < bytes.count, Self.isSpace(bytes[end]) { end += 1 }
            return [(range.lowerBound..<end, "")]
        }
        if index > 0, let previous = commaAfter(children[index - 1].upperBound, in: container) {
            return [(previous..<range.upperBound, "")]
        }
        // The only child, inline: `{ "a": 1 }` becomes `{}`.
        return [((container.range.lowerBound + 1)..<(container.range.upperBound - 1), "")]
    }

    // MARK: Finding things

    private func node(at path: [Key]) -> Node? {
        var node = root
        for key in path {
            switch (key, node.kind) {
            case (.name(let name), .object):
                guard let member = node.members.last(where: { $0.key == name }) else { return nil }
                node = member.value
            case (.index(let index), .array) where node.items.indices.contains(index):
                node = node.items[index]
            default:
                return nil
            }
        }
        return node
    }

    /// The container holding `path`'s last key, and the child's index in it.
    private func child(at path: [Key]) -> (Node, Int)? {
        guard let last = path.last, let parent = node(at: Array(path.dropLast())) else { return nil }
        switch (last, parent.kind) {
        case (.name(let name), .object):
            return parent.members.lastIndex(where: { $0.key == name }).map { (parent, $0) }
        case (.index(let index), .array) where parent.items.indices.contains(index):
            return (parent, index)
        default:
            return nil
        }
    }

    private func missingItem(_ key: Key, in node: Node) -> ParseError {
        let (line, column) = Parser.position(of: node.range.lowerBound, in: bytes)
        let what = if case .index(let index) = key { "no item \(index)" } else { "not an object" }
        return ParseError(line: line, column: column, message: what)
    }

    /// The `,` after a child's value, skipping spaces and comments, if it comes before the
    /// container ends.
    private func commaAfter(_ offset: Int, in container: Node) -> Int? {
        var parser = Parser(bytes: bytes)
        parser.offset = offset
        guard (try? parser.skipTrivia()) != nil, parser.offset < container.range.upperBound, bytes[parser.offset] == UInt8(ascii: ",") else { return nil }
        return parser.offset
    }

    /// A child with only spaces before it on its first line, and only its comma and a comment
    /// after it on its last.
    private func isAlone(_ range: Range<Int>, in container: Node) -> Bool {
        guard isFirstOnLine(range.lowerBound) else { return false }
        let after = commaAfter(range.upperBound, in: container).map { $0 + 1 } ?? range.upperBound
        return restOfLineIsComment(after)
    }

    private func isFirstOnLine(_ offset: Int) -> Bool {
        bytes[lineStart(offset)..<offset].allSatisfy(Self.isSpace)
    }

    /// Only spaces, and maybe a `//` comment or a `/* */` that ends on this line, up to the line break.
    private func restOfLineIsComment(_ offset: Int) -> Bool {
        var index = offset
        let end = lineEnd(offset)
        while index < end, Self.isSpace(bytes[index]) { index += 1 }
        if index == end { return true }
        guard index + 1 < end, bytes[index] == UInt8(ascii: "/") else { return false }
        if bytes[index + 1] == UInt8(ascii: "/") { return true }
        guard bytes[index + 1] == UInt8(ascii: "*") else { return false }
        index += 2
        while index + 1 < end, !(bytes[index] == UInt8(ascii: "*") && bytes[index + 1] == UInt8(ascii: "/")) { index += 1 }
        guard index + 1 < end else { return false }
        return bytes[(index + 2)..<end].allSatisfy(Self.isSpace)
    }

    private func lineStart(_ offset: Int) -> Int {
        var index = offset
        while index > 0, bytes[index - 1] != UInt8(ascii: "\n") { index -= 1 }
        return index
    }

    /// Where the line's break starts: its `\r\n` or `\n`, or the end of the text.
    private func lineEnd(_ offset: Int) -> Int {
        var index = offset
        while index < bytes.count, bytes[index] != UInt8(ascii: "\n") { index += 1 }
        if index > offset, index < bytes.count, bytes[index - 1] == UInt8(ascii: "\r") { index -= 1 }
        return index
    }

    private func line(of offset: Int) -> Int {
        bytes[..<offset].reduce(0) { $1 == UInt8(ascii: "\n") ? $0 + 1 : $0 }
    }

    /// The spaces at the start of the line `offset` is on.
    private func indentation(of offset: Int) -> String {
        let start = lineStart(offset)
        var end = start
        while end < bytes.count, Self.isSpace(bytes[end]) { end += 1 }
        return String(decoding: bytes[start..<end], as: UTF8.self)
    }

    private static func isSpace(_ byte: UInt8) -> Bool { byte == 0x20 || byte == 0x09 }
    private static func isWhitespace(_ byte: UInt8) -> Bool { isSpace(byte) || byte == 0x0A || byte == 0x0D }

    // MARK: Writing values

    /// One line of JSON: `{ "panel": "ci", "size": "2x1" }`, `[1, 2]`.
    static func render(_ value: Value) -> String {
        switch value {
        case .string(let string): quote(string)
        case .number(let number):
            number == number.rounded() && abs(number) < 1e15 ? String(Int(number)) : String(number)
        case .bool(let bool): bool ? "true" : "false"
        case .null: "null"
        case .array(let items): items.isEmpty ? "[]" : "[" + items.map(render).joined(separator: ", ") + "]"
        case .object(let members):
            members.isEmpty ? "{}" : "{ " + members.map { "\(quote($0.0)): \(render($0.1))" }.joined(separator: ", ") + " }"
        }
    }

    private static func quote(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }
}

// MARK: Parsing

private struct Node: Sendable {
    enum Kind: Sendable { case object, array, scalar }

    struct Member: Sendable {
        var key: String
        var keyRange: Range<Int>
        var value: Node
    }

    var kind: Kind
    var range: Range<Int>
    var members: [Member] = []
    var items: [Node] = []

    /// Each member from its key to the end of its value, or each item.
    var childRanges: [Range<Int>] {
        kind == .object ? members.map { $0.keyRange.lowerBound..<$0.value.range.upperBound } : items.map(\.range)
    }
}

private struct Parser {
    let bytes: [UInt8]
    var offset = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    mutating func parseDocument() throws(JSONCDocument.ParseError) -> Node {
        try skipTrivia()
        let node = try parseValue()
        try skipTrivia()
        guard offset == bytes.count else { throw error("unexpected text after the value") }
        return node
    }

    mutating func skipTrivia() throws(JSONCDocument.ParseError) {
        while offset < bytes.count {
            let byte = bytes[offset]
            if byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D {
                offset += 1
            } else if byte == UInt8(ascii: "/"), offset + 1 < bytes.count, bytes[offset + 1] == UInt8(ascii: "/") {
                while offset < bytes.count, bytes[offset] != 0x0A { offset += 1 }
            } else if byte == UInt8(ascii: "/"), offset + 1 < bytes.count, bytes[offset + 1] == UInt8(ascii: "*") {
                let start = offset
                offset += 2
                while offset + 1 < bytes.count, !(bytes[offset] == UInt8(ascii: "*") && bytes[offset + 1] == UInt8(ascii: "/")) { offset += 1 }
                guard offset + 1 < bytes.count else { throw error("unterminated comment", at: start) }
                offset += 2
            } else if offset == 0, bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
                offset += 3
            } else {
                return
            }
        }
    }

    private mutating func parseValue() throws(JSONCDocument.ParseError) -> Node {
        guard offset < bytes.count else { throw error("expected a value") }
        switch bytes[offset] {
        case UInt8(ascii: "{"): return try parseObject()
        case UInt8(ascii: "["): return try parseArray()
        case UInt8(ascii: "\""), UInt8(ascii: "'"):
            let start = offset
            try skipString()
            return Node(kind: .scalar, range: start..<offset)
        default:
            let start = offset
            while offset < bytes.count, Self.isScalarByte(bytes[offset]) { offset += 1 }
            guard offset > start else { throw error("expected a value") }
            return Node(kind: .scalar, range: start..<offset)
        }
    }

    private mutating func parseObject() throws(JSONCDocument.ParseError) -> Node {
        let start = offset
        offset += 1
        var members: [Node.Member] = []
        try skipTrivia()
        while offset < bytes.count, bytes[offset] != UInt8(ascii: "}") {
            let keyStart = offset
            let key: String
            if bytes[offset] == UInt8(ascii: "\"") || bytes[offset] == UInt8(ascii: "'") {
                try skipString()
                key = Self.decodeString(bytes[keyStart..<offset]) ?? ""
            } else {
                while offset < bytes.count, Self.isKeyByte(bytes[offset]) { offset += 1 }
                guard offset > keyStart else { throw error(#"expected "," or "}""#) }
                key = String(decoding: bytes[keyStart..<offset], as: UTF8.self)
            }
            let keyRange = keyStart..<offset
            try skipTrivia()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: ":") else { throw error(#"expected ":""#) }
            offset += 1
            try skipTrivia()
            let value = try parseValue()
            members.append(Node.Member(key: key, keyRange: keyRange, value: value))
            try skipTrivia()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: ",") || bytes[offset] == UInt8(ascii: "}") else {
                throw error(#"expected "," or "}""#)
            }
            if bytes[offset] == UInt8(ascii: ",") {
                offset += 1
                try skipTrivia()
            }
        }
        guard offset < bytes.count else { throw error(#"expected "," or "}""#) }
        offset += 1
        return Node(kind: .object, range: start..<offset, members: members)
    }

    private mutating func parseArray() throws(JSONCDocument.ParseError) -> Node {
        let start = offset
        offset += 1
        var items: [Node] = []
        try skipTrivia()
        while offset < bytes.count, bytes[offset] != UInt8(ascii: "]") {
            items.append(try parseValue())
            try skipTrivia()
            guard offset < bytes.count, bytes[offset] == UInt8(ascii: ",") || bytes[offset] == UInt8(ascii: "]") else {
                throw error(#"expected "," or "]""#)
            }
            if bytes[offset] == UInt8(ascii: ",") {
                offset += 1
                try skipTrivia()
            }
        }
        guard offset < bytes.count else { throw error(#"expected "," or "]""#) }
        offset += 1
        return Node(kind: .array, range: start..<offset, items: items)
    }

    /// Past a quoted string and its closing quote. A string ends at its line.
    private mutating func skipString() throws(JSONCDocument.ParseError) {
        let start = offset
        let quote = bytes[offset]
        offset += 1
        while offset < bytes.count {
            let byte = bytes[offset]
            if byte == quote {
                offset += 1
                return
            }
            if byte == 0x0A { break }
            // An escaped line break continues the string, as in JSON5.
            offset += byte == UInt8(ascii: "\\") ? 2 : 1
        }
        throw error("unterminated string", at: start)
    }

    private static func decodeString(_ slice: ArraySlice<UInt8>) -> String? {
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try? decoder.decode(String.self, from: Data(slice))
    }

    private static func isScalarByte(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
            || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-")
    }

    private static func isKeyByte(_ byte: UInt8) -> Bool {
        (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
            || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "$")
    }

    private func error(_ message: String, at position: Int? = nil) -> JSONCDocument.ParseError {
        let (line, column) = Self.position(of: position ?? offset, in: bytes)
        return JSONCDocument.ParseError(line: line, column: column, message: message)
    }

    /// 1-based line and column, the column in characters.
    static func position(of offset: Int, in bytes: [UInt8]) -> (line: Int, column: Int) {
        let before = bytes[..<min(offset, bytes.count)]
        let line = before.reduce(1) { $1 == 0x0A ? $0 + 1 : $0 }
        let start = before.lastIndex(of: 0x0A).map { $0 + 1 } ?? 0
        return (line, String(decoding: bytes[start..<min(offset, bytes.count)], as: UTF8.self).count + 1)
    }
}
