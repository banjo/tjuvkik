import Foundation
import Testing
@testable import TjuvkikCore

private func load(_ text: String) -> Result<LoadedConfig, ConfigErrors> {
    ConfigLoader.parse(Data(text.utf8))
}

private func errors(_ text: String) -> [String] {
    guard case .failure(let errors) = load(text) else { return [] }
    return errors.issues.map(\.description)
}

private func config(_ text: String) throws -> LoadedConfig {
    try load(text).get()
}

struct ThemeTests {
    @Test func customThemeOverridesTokens() throws {
        let theme = try config(##"{ "theme": "mine", "themes": { "mine": { "extends": "dracula", "accent": "#ff79c6", "radius": 4 } } }"##).config.theme
        #expect(theme.accent == RGBA(hex: "#ff79c6"))
        #expect(theme.radius == 4)
        #expect(theme.panel == Theme.dracula.panel)
    }

    @Test func customThemeDefaultsToDarkGlass() throws {
        let theme = try config(#"{ "theme": "mine", "themes": { "mine": { "blur": false } } }"#).config.theme
        #expect(theme.blur == false)
        #expect(theme.text == Theme.darkGlass.text)
    }

    @Test func themesCanExtendCustomThemes() throws {
        let theme = try config(#"{ "theme": "b", "themes": { "a": { "extends": "light-glass", "radius": 2 }, "b": { "extends": "a" } } }"#).config.theme
        #expect(theme.appearance == .light)
        #expect(theme.radius == 2)
    }

    @Test func loopIsAnError() {
        #expect(errors(#"{ "theme": "a", "themes": { "a": { "extends": "b" }, "b": { "extends": "a" } } }"#)
            == ["themes.a.extends: themes extend each other in a loop: a → b → a"])
    }

    @Test func badColorIsAnError() {
        #expect(errors(#"{ "theme": "a", "themes": { "a": { "accent": "pink" } } }"#)
            == [##"themes.a.accent: can't read color "pink", write it like "#ff79c6" or "#ff79c680""##])
    }

    @Test func hexForms() {
        #expect(RGBA(hex: "#fff") == RGBA(red: 1, green: 1, blue: 1))
        #expect(RGBA(hex: "#00000080")?.alpha == 128.0 / 255)
        #expect(RGBA(hex: "ffffff") == nil)
        #expect(RGBA(hex: "#12345") == nil)
    }
}
