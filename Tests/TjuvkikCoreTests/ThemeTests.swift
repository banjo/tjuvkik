import Testing
@testable import TjuvkikCore

struct ThemeTests {
    @Test func customThemeOverridesTokens() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": ##"{ "extends": "dracula", "accent": "#ff79c6", "radius": 4 }"##,
        ]).config.theme
        #expect(theme.accent == RGBA(hex: "#ff79c6"))
        #expect(theme.radius == 4)
        #expect(theme.panel == Theme.dracula.panel)
    }

    @Test func customThemeDefaultsToDarkGlass() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": #"{ "blur": false }"#,
        ]).config.theme
        #expect(theme.blur == false)
        #expect(theme.text == Theme.darkGlass.text)
    }

    @Test func themesCanExtendCustomThemes() throws {
        let theme = try load([
            "config.json": #"{ "theme": "b" }"#,
            "themes/a.json": #"{ "extends": "light-glass", "radius": 2 }"#,
            "themes/b.json": #"{ "extends": "a" }"#,
        ]).config.theme
        #expect(theme.appearance == .light)
        #expect(theme.radius == 2)
    }

    @Test func unknownThemeListsTheFiles() {
        #expect(errors(["config.json": #"{ "theme": "nope" }"#, "themes/mine.json": "{}"])
            == [#"config.json: theme: unknown theme "nope", expected one of "dark-glass", "dracula", "light-glass", "mine""#])
    }

    @Test func loopIsAnError() {
        #expect(errors([
            "config.json": #"{ "theme": "a" }"#,
            "themes/a.json": #"{ "extends": "b" }"#,
            "themes/b.json": #"{ "extends": "a" }"#,
        ]) == ["themes/b.json: extends: themes extend each other in a loop: a → b → a"])
    }

    @Test func badColorIsAnError() {
        #expect(errors([
            "config.json": #"{ "theme": "a" }"#,
            "themes/a.json": #"{ "accent": "pink" }"#,
        ]) == [##"themes/a.json: accent: can't read color "pink", write it like "#ff79c6" or "#ff79c680""##])
    }

    @Test func builtInNameInThemesIsIgnoredWithAWarning() throws {
        let loaded = try load([
            "config.json": #"{ "theme": "dracula" }"#,
            "themes/dracula.json": #"{ "radius": 0 }"#,
        ])
        #expect(loaded.config.theme == .dracula)
        #expect(loaded.warnings.map(\.file) == ["themes/dracula.json"])
    }

    @Test func hexForms() {
        #expect(RGBA(hex: "#fff") == RGBA(red: 1, green: 1, blue: 1))
        #expect(RGBA(hex: "#00000080")?.alpha == 128.0 / 255)
        #expect(RGBA(hex: "ffffff") == nil)
        #expect(RGBA(hex: "#12345") == nil)
    }
}
