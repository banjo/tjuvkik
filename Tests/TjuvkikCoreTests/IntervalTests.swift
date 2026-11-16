import Testing
@testable import TjuvkikCore

struct IntervalTests {
    @Test func units() {
        #expect(Interval.seconds("30s") == 30)
        #expect(Interval.seconds("5m") == 300)
        #expect(Interval.seconds("1h") == 3600)
        #expect(Interval.seconds("500ms") == 0.5)
        #expect(Interval.seconds(" 2M ") == 120)
    }

    @Test func rejects() {
        #expect(Interval.seconds("5") == nil)
        #expect(Interval.seconds("0s") == nil)
        #expect(Interval.seconds("-1m") == nil)
        #expect(Interval.seconds("soon") == nil)
    }
}
