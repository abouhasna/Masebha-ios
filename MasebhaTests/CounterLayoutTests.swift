import CoreGraphics
import Testing
@testable import Masebha

/// The counter screen layout rule for long dhikr (owner's requirement):
/// the ring never goes under its minimum, and the text window shows at most 4 lines.
struct CounterLayoutTests {
    // iPhone 17-like values: 402 pt wide, ~660 pt between the toolbar and the previous/next bar.
    private let width: CGFloat = 402
    private let height: CGFloat = 660
    private let stats: CGFloat = 80
    private let line: CGFloat = 40

    @Test func shortTextGetsTheFullRing() {
        let result = CounterLayout.scrolling(availableHeight: height, width: width, statsHeight: stats,
                                             textHeight: line, lineHeight: line)
        #expect(result.textWindowHeight == line)
        #expect(result.ringDiameter == CounterLayout.maximumRing(width: width))   // 330 on this width
    }

    @Test func longTextIsLimitedToFourLines() {
        let result = CounterLayout.scrolling(availableHeight: 900, width: width, statsHeight: stats,
                                             textHeight: line * 20, lineHeight: line)
        #expect(result.textWindowHeight == line * 4)
    }

    @Test(arguments: [500, 560, 620, 660, 760] as [CGFloat])
    func theRingNeverGoesUnderItsMinimum(availableHeight: CGFloat) {
        let result = CounterLayout.scrolling(availableHeight: availableHeight, width: width, statsHeight: stats,
                                             textHeight: line * 20, lineHeight: line)
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(result.ringDiameter <= CounterLayout.maximumRing(width: width))
        // Everything fits: text window + stats + ring + paddings <= available height (when it can).
        let used = CounterLayout.textTopPadding + result.textWindowHeight + stats
            + 2 * CounterLayout.ringVerticalPadding + result.ringDiameter
        if availableHeight >= CounterLayout.textTopPadding + line + stats
            + 2 * CounterLayout.ringVerticalPadding + CounterLayout.ringMinimum {
            #expect(used <= availableHeight + 0.5)
        }
    }

    @Test func textWindowShrinksBeforeTheRingDoes() {
        // Big font: the 4-line window would not leave room for the minimum ring, so it gets smaller.
        let bigLine: CGFloat = 60
        let result = CounterLayout.scrolling(availableHeight: 620, width: width, statsHeight: 110,
                                             textHeight: bigLine * 6, lineHeight: bigLine)
        #expect(result.textWindowHeight < bigLine * 4)
        #expect(result.textWindowHeight >= bigLine)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
    }

    @Test func narrowScreenRingFitsTheWidth() {
        let narrow: CGFloat = 320
        #expect(CounterLayout.maximumRing(width: narrow) == narrow - 72)
        let result = CounterLayout.scrolling(availableHeight: height, width: narrow, statsHeight: stats,
                                             textHeight: line, lineHeight: line)
        #expect(result.ringDiameter <= narrow - 72)
    }
}
