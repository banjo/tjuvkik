import Foundation

/// A key with modifiers, like `⌃⌥Space` or `ctrl+option+space`. Keys are named by where they
/// sit on a US keyboard, as macOS registers shortcuts by key position.
public struct Shortcut: Equatable, Sendable, CustomStringConvertible {
    public struct Modifiers: OptionSet, Equatable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var modifiers: Modifiers
    /// The macOS virtual key code.
    public var keyCode: UInt32
    /// "Space", "G", "F5".
    public var key: String

    /// `⌃⌥⇧⌘` in the order macOS writes them, then the key.
    public var description: String {
        let symbols: [(Modifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key
    }

    public static func parse(_ text: String) -> Result<Shortcut, ShortcutError> {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(ShortcutError("is empty")) }

        // "ctrl+option+space", "⌃⌥Space" and "⌃⌥+space" all work: split on "+", and read
        // modifier symbols off the front of each part.
        var parts = trimmed.split(separator: "+", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var modifiers: Modifiers = []
        var keyName = parts.removeLast()
        for part in parts {
            if let modifier = modifierWords[part.lowercased()] {
                modifiers.insert(modifier)
                continue
            }
            var rest = Substring(part)
            while let first = rest.first, let modifier = modifierSymbols[first] {
                modifiers.insert(modifier)
                rest = rest.dropFirst()
            }
            guard rest.isEmpty else { return .failure(ShortcutError("\"\(part)\" isn't a modifier, expected ctrl, option, shift or cmd")) }
        }
        while let first = keyName.first, let modifier = modifierSymbols[first] {
            modifiers.insert(modifier)
            keyName.removeFirst()
        }
        guard !keyName.isEmpty else { return .failure(ShortcutError("needs a key after the modifiers, like ⌃⌥Space")) }
        if modifierWords[keyName.lowercased()] != nil {
            return .failure(ShortcutError("needs a key after the modifiers, like ⌃⌥Space; to use a modifier on its own, set \"key\""))
        }
        guard let (code, name) = key(keyName) else {
            return .failure(ShortcutError("unknown key \"\(keyName)\", expected a letter, a digit, Space, Return, Tab, an arrow or F1–F20"))
        }
        let isFunctionKey = name.hasPrefix("F") && name.count > 1
        if !isFunctionKey && modifiers.isDisjoint(with: [.control, .option, .command]) {
            return .failure(ShortcutError("needs ⌃, ⌥ or ⌘, so it doesn't take a key you type"))
        }
        return .success(Shortcut(modifiers: modifiers, keyCode: code, key: name))
    }

    private static let modifierWords: [String: Modifiers] = [
        "ctrl": .control, "control": .control, "⌃": .control,
        "opt": .option, "option": .option, "alt": .option, "⌥": .option,
        "shift": .shift, "⇧": .shift,
        "cmd": .command, "command": .command, "⌘": .command,
    ]

    private static let modifierSymbols: [Character: Modifiers] = ["⌃": .control, "⌥": .option, "⇧": .shift, "⌘": .command]

    /// A key's code and how it's written.
    private static func key(_ name: String) -> (UInt32, String)? {
        let lower = name.lowercased()
        if lower.count == 1, let code = characters[Character(lower)] {
            return (code, name.uppercased())
        }
        if let (code, written) = named[lower] { return (code, written) }
        if lower.hasPrefix("f"), let number = Int(lower.dropFirst()), (1...20).contains(number) {
            return (functionKeys[number - 1], "F\(number)")
        }
        return nil
    }

    private static let characters: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50,
        "←": 123, "→": 124, "↓": 125, "↑": 126,
    ]

    private static let named: [String: (UInt32, String)] = [
        "space": (49, "Space"), "return": (36, "Return"), "enter": (36, "Return"), "tab": (48, "Tab"),
        "escape": (53, "Esc"), "esc": (53, "Esc"), "delete": (51, "Delete"),
        "left": (123, "←"), "right": (124, "→"), "down": (125, "↓"), "up": (126, "↑"),
    ]

    private static let functionKeys: [UInt32] = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    ]
}

public struct ShortcutError: Error, Equatable, Sendable {
    public var message: String
    init(_ message: String) { self.message = message }
}
