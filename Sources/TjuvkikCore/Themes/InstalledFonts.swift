import CoreText

/// Font families on this Mac, as Font Book names them.
enum InstalledFonts {
    static func has(_ family: String) -> Bool {
        families.contains(family.lowercased())
    }

    private static let families: Set<String> = {
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        return Set(names.map { $0.lowercased() })
    }()
}
