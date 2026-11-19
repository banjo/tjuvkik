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

    private let board = BentoGeometry.board(.standard, theme: .darkGlass)

    @Test func theStandardBoardIsTheOldSize() {
        #expect(board == CGSize(width: 1080, height: 580))
    }

    @Test func framedOnALaptop() {
        let framed = GlancePlacement.framed(in: CGRect(x: 0, y: 0, width: 1512, height: 944), content: board, zoom: .auto)
        #expect(framed.zoom == 1)
        #expect(framed.rect.size == CGSize(width: 1080, height: 580))
        #expect(framed.rect.midX == 756)
        #expect(abs(framed.rect.maxY - 821) <= 1)
    }

    @Test func autoZoomsInOnABigScreen() {
        let framed = GlancePlacement.framed(in: CGRect(x: 0, y: 0, width: 2560, height: 1415), content: board, zoom: .auto)
        #expect(abs(framed.zoom - 2560 / 1728) < 0.001)
        #expect(abs(framed.rect.width / framed.rect.height - board.width / board.height) < 0.01)
    }

    @Test func autoStopsAtItsLimit() {
        let framed = GlancePlacement.framed(in: CGRect(x: 0, y: 0, width: 5120, height: 2880), content: board, zoom: .auto)
        #expect(framed.zoom == GlancePlacement.autoZoomLimit)
    }

    @Test func aFixedZoomIsKept() {
        let framed = GlancePlacement.framed(in: CGRect(x: 0, y: 0, width: 1512, height: 944), content: board, zoom: .fixed(0.9))
        #expect(abs(framed.zoom - 0.9) < 0.001)
    }

    @Test func framedShrinksOnASmallScreenAndKeepsItsShape() {
        let framed = GlancePlacement.framed(in: CGRect(x: 2000, y: 100, width: 800, height: 600), content: board, zoom: .fixed(1.5))
        #expect(framed.rect.width == 752)
        #expect(framed.zoom < 1)
        #expect(abs(framed.rect.width / framed.rect.height - board.width / board.height) < 0.01)
        #expect(framed.rect.midX == 2400)
    }

    @Test func aTallGridShrinksToTheHeight() {
        let tall = BentoGeometry.board(BoardGrid(columns: 4, rows: 6), theme: .darkGlass)
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let framed = GlancePlacement.framed(in: screen, content: tall, zoom: .auto)
        #expect(framed.zoom < 1)
        #expect(framed.rect.minY >= screen.minY)
    }
}
