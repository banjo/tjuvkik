import Testing
@testable import TjuvkikCore

struct HoldGestureTests {
    @Test func holdShowsAndReleaseHides() {
        var g = HoldGesture()
        #expect(g.handle(.fnDown(otherModifiers: false)) == [.startTimer])
        #expect(g.handle(.timerFired) == [.show])
        #expect(g.isShown)
        #expect(g.handle(.fnUp) == [.hide])
        #expect(!g.isShown)
    }

    @Test func quickTapNeverShows() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        #expect(g.handle(.fnUp) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
    }

    @Test func keyBeforeTimerCancels() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        #expect(g.handle(.keyDown) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(.fnUp) == [])
    }

    @Test func keyWhileShownHides() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        _ = g.handle(.timerFired)
        #expect(g.handle(.keyDown) == [.hide])
        #expect(g.handle(.fnUp) == [])
    }

    @Test func otherModifierCancels() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        #expect(g.handle(.modifiersChanged) == [.cancelTimer])
        #expect(g.handle(.timerFired) == [])
    }

    @Test func fnWithModifierHeldDoesNothing() {
        var g = HoldGesture()
        #expect(g.handle(.fnDown(otherModifiers: true)) == [])
        #expect(g.handle(.timerFired) == [])
        #expect(g.handle(.fnUp) == [])
    }

    @Test func repeatedFnDownIsIgnored() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        #expect(g.handle(.fnDown(otherModifiers: false)) == [])
        #expect(g.handle(.timerFired) == [.show])
    }

    @Test func worksAgainAfterCancel() {
        var g = HoldGesture()
        _ = g.handle(.fnDown(otherModifiers: false))
        _ = g.handle(.keyDown)
        _ = g.handle(.fnUp)
        #expect(g.handle(.fnDown(otherModifiers: false)) == [.startTimer])
    }
}
