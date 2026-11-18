import Foundation
import Testing
@testable import TjuvkikCore

struct RowActionsTests {
    @Test func rowsReadActions() throws {
        let json = #"""
        { "rows": [{ "title": "PR", "url": "https://x", "actionTitle": "Open PR",
                     "actions": [{ "title": "Approve", "command": "gh pr review --approve", "key": "A" },
                                 { "title": "Copy", "copy": "x", "key": "c" },
                                 { "title": "Long", "key": "ab" }] }] }
        """#
        guard case .success(.rows(let content)) = ScriptOutput.content(Data(json.utf8)) else { Issue.record("not rows"); return }
        let actions = content.rows[0].actions
        #expect(actions.title == "Open PR")
        #expect(actions.actions.map(\.title) == ["Approve", "Copy", "Long"])
        // Lowercased; c is the glance's copy, and two letters aren't a key.
        #expect(actions.actions.map(\.key) == ["a", nil, nil])
    }

    @Test func otherTypesReadActions() throws {
        let json = #"{ "items": [{ "text": "hi", "actions": [{ "title": "Reply", "url": "slack://x" }] }] }"#
        guard case .success(.feed(let content)) = ScriptOutput.content(Data(json.utf8)) else { Issue.record("not a feed"); return }
        #expect(content.items[0].actions.actions.first?.url == "slack://x")
    }
}
