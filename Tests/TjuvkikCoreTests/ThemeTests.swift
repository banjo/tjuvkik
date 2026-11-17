import Testing
@testable import TjuvkikCore

struct ThemeTests {
    @Test func customThemeOverridesTokens() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": ##"{ "extends": "dracula", "accent": "#ff79c6", "radius": 4 }"##,
        ]).config.darkTheme
        #expect(theme.accent == RGBA(hex: "#ff79c6"))
        #expect(theme.radius == 4)
        #expect(theme.panel == Theme.dracula.panel)
    }

    @Test func customThemeDefaultsToDarkGlass() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": #"{ "blur": false }"#,
        ]).config.darkTheme
        #expect(theme.blur == false)
        #expect(theme.text == Theme.darkGlass.text)
    }

    @Test func themesCanExtendCustomThemes() throws {
        let theme = try load([
            "config.json": #"{ "theme": "b" }"#,
            "themes/a.json": #"{ "extends": "light-glass", "radius": 2 }"#,
            "themes/b.json": #"{ "extends": "a" }"#,
        ]).config.darkTheme
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
        #expect(loaded.config.darkTheme == .dracula)
        #expect(loaded.warnings.map(\.file) == ["themes/dracula.json"])
    }

    @Test func newTokensDefaultToTodaysLook() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": #"{ "extends": "dracula" }"#,
        ]).config.darkTheme
        #expect(theme.material == .hud)
        #expect(theme.font == Theme.Fonts())
        #expect(theme.board == Theme.Board())
        #expect(theme.tile == Theme.TileStyle())
        #expect(theme.toneBackgrounds == [:])
    }

    @Test func everyNewTokenLands() throws {
        let theme = try load([
            "config.json": #"{ "theme": "mine" }"#,
            "themes/mine.json": ##"""
            {
              "material": "popover",
              "font": { "family": "Helvetica", "mono": "Menlo", "scale": 1.1 },
              "board": { "gap": 6, "inset": 12 },
              "tile": { "border": 0, "shadow": false, "padding": 10, "header": { "uppercase": true, "kind": false, "interval": false } },
              "tones": { "error": { "background": "#ff000020" } }
            }
            """##,
        ]).config.darkTheme
        #expect(theme.material == .popover)
        #expect(theme.font.family == "Helvetica")
        #expect(theme.font.mono == "Menlo")
        #expect(theme.font.scale == 1.1)
        #expect(theme.board.gap == 6)
        #expect(theme.board.inset == 12)
        #expect(theme.tile.border == 0)
        #expect(theme.tile.shadow == false)
        #expect(theme.tile.padding == 10)
        #expect(theme.tile.uppercaseTitle)
        #expect(theme.tile.showKind == false)
        #expect(theme.tile.showInterval == false)
        #expect(theme.toneBackgrounds == [.error: RGBA(hex: "#ff000020")!])
    }

    @Test func extendsKeyByKey() throws {
        let theme = try load([
            "config.json": #"{ "theme": "b" }"#,
            "themes/a.json": #"{ "font": { "family": "Helvetica" } }"#,
            "themes/b.json": #"{ "extends": "a", "font": { "scale": 1.2 } }"#,
        ]).config.darkTheme
        #expect(theme.font.family == "Helvetica")
        #expect(theme.font.scale == 1.2)
    }

    @Test func missingFontIsAWarning() throws {
        let loaded = try load([
            "config.json": #"{ "theme": "x" }"#,
            "themes/x.json": #"{ "font": { "family": "No Such Font 123" } }"#,
        ])
        #expect(loaded.warnings.map(\.description) == [#"themes/x.json: font.family: "No Such Font 123" isn't installed, using the system font"#])
        #expect(loaded.config.darkTheme.font.family == nil)
    }

    @Test func badNewTokensAreErrors() {
        func theme(_ json: String) -> [String] {
            errors(["config.json": #"{ "theme": "x" }"#, "themes/x.json": json])
        }
        #expect(theme(#"{ "material": "glass" }"#)
            == [#"themes/x.json: material: unknown material "glass", expected "hud", "popover", "menu", "sidebar" or "underWindow""#])
        #expect(theme(#"{ "font": { "scale": 2 } }"#) == ["themes/x.json: font.scale: must be between 0.85 and 1.25, got 2"])
        #expect(theme(#"{ "board": { "gap": 30 } }"#) == ["themes/x.json: board.gap: must be between 0 and 24, got 30"])
        #expect(theme(#"{ "tile": { "padding": 2 } }"#) == ["themes/x.json: tile.padding: must be between 6 and 20, got 2"])
        #expect(theme(#"{ "tones": { "loud": {} } }"#)
            == [#"themes/x.json: tones.loud: unknown tone, expected "muted", "warning", "error", "success", "info" or "accent""#])
        #expect(theme(#"{ "tones": { "normal": {} } }"#)
            == [#"themes/x.json: tones.normal: unknown tone, expected "muted", "warning", "error", "success", "info" or "accent""#])
        #expect(theme(#"{ "tones": { "error": { "background": "red" } } }"#)
            == [##"themes/x.json: tones.error.background: can't read color "red", write it like "#ff79c6" or "#ff79c680""##])
    }

    @Test func hexForms() {
        #expect(RGBA(hex: "#fff") == RGBA(red: 1, green: 1, blue: 1))
        #expect(RGBA(hex: "#00000080")?.alpha == 128.0 / 255)
        #expect(RGBA(hex: "ffffff") == nil)
        #expect(RGBA(hex: "#12345") == nil)
    }
}
