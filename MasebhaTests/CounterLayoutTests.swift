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

    // Measured on the iPhone 17 screenshot with the biggest font (42) and the "today" row:
    // statistics block ≈ 214 pt, one dhikr line ≈ 61 pt.
    private let hugeStats: CGFloat = 214
    private let hugeLine: CGFloat = 61

    private func used(_ result: CounterLayout.Result, stats: CGFloat) -> CGFloat {
        CounterLayout.textTopPadding + result.textWindowHeight + stats
            + 2 * CounterLayout.ringVerticalPadding + result.ringDiameter
    }

    /// iPhones with Face ID (mini to Pro Max), biggest font + "today" row: the ring keeps at least
    /// its minimum and everything fits above the previous/next buttons.
    @Test(arguments: [(375, 812), (390, 844), (402, 874), (440, 956)] as [(CGFloat, CGFloat)])
    func faceIDiPhonesKeepTheMinimumRing(width: CGFloat, screenHeight: CGFloat) {
        let available = screenHeight - 116 - 60 - 34   // toolbar + status bar, buttons, home bar
        let result = CounterLayout.scrolling(availableHeight: available, width: width, statsHeight: hugeStats,
                                             textHeight: hugeLine * 3, lineHeight: hugeLine)
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(used(result, stats: hugeStats) <= available + 0.5)
    }

    /// 4.7" iPhone SE (375 x 667), biggest font + "today" row: there is not enough height for the
    /// 240 pt ring, so it shrinks (to about 208 pt) instead of going under the buttons.
    @Test func iPhoneSEWithBiggestFontAndTodayRowShrinksTheRingToFit() {
        let available: CGFloat = 667 - 64 - 60   // status bar + toolbar, buttons (no home bar)
        let result = CounterLayout.scrolling(availableHeight: available, width: 375, statsHeight: hugeStats,
                                             textHeight: hugeLine * 3, lineHeight: hugeLine)
        #expect(result.textWindowHeight == hugeLine)   // one line visible, the rest scrolls
        #expect(result.ringDiameter > 200 && result.ringDiameter < CounterLayout.ringMinimum)
        #expect(used(result, stats: hugeStats) <= available + 0.5)
    }

    /// Same iPhone SE with the biggest font but without the "today" row: the full minimum again.
    @Test func iPhoneSEWithBiggestFontKeepsTheMinimumRing() {
        let available: CGFloat = 667 - 64 - 60
        let oneRowStats: CGFloat = 24 + 88
        let result = CounterLayout.scrolling(availableHeight: available, width: 375, statsHeight: oneRowStats,
                                             textHeight: hugeLine * 3, lineHeight: hugeLine)
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(used(result, stats: oneRowStats) <= available + 0.5)
    }

    @Test func narrowScreenRingFitsTheWidth() {
        let narrow: CGFloat = 320
        #expect(CounterLayout.maximumRing(width: narrow) == narrow - 72)
        let result = CounterLayout.scrolling(availableHeight: height, width: narrow, statsHeight: stats,
                                             textHeight: line, lineHeight: line)
        #expect(result.ringDiameter <= narrow - 72)
    }
}
