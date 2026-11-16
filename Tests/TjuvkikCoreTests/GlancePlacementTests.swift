import CoreGraphics
import Testing
@testable import TjuvkikCore

struct GlancePlacementTests {
    @Test func flipsQuartzToAppKit() {
        let rect = GlancePlacement.appKitRect(fromQuartz: CGRect(x: 10, y: 20, width: 100, height: 50), primaryScreenHeight: 1000)
        #expect(rect == CGRect(x: 10, y: 930, width: 100, height: 50))
    }

    @Test func picksTheScreenWithTheMostOverlap() {
        let left = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let right = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let window = CGRect(x: 1400, y: 100, width: 800, height: 600)
        #expect(GlancePlacement.screenIndex(for: window, screens: [left, right]) == 1)
    }

    @Test func noScreenForAWindowOffScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        #expect(GlancePlacement.screenIndex(for: CGRect(x: 5000, y: 0, width: 10, height: 10), screens: [screen]) == nil)
    }

    @Test func framedOnALaptop() {
        let rect = GlancePlacement.framedRect(in: CGRect(x: 0, y: 0, width: 1512, height: 944))
        #expect(rect.width == 1080)
        #expect(rect.height == 580)
        #expect(rect.midX == 756)
        #expect(abs(rect.maxY - 821) <= 1)
    }

    @Test func framedShrinksOnASmallScreen() {
        let rect = GlancePlacement.framedRect(in: CGRect(x: 2000, y: 100, width: 800, height: 600))
        #expect(rect.width == 752)
        #expect(rect.height == 396)
        #expect(rect.midX == 2400)
    }
}
