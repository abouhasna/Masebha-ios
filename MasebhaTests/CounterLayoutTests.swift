import CoreGraphics
import Testing
@testable import Masebha

/// The counter / wird layout rule (owner's requirement): the text has priority.
/// 1. normal text → full text, biggest ring; 2. long text → full text, smaller ring (≥ minimum);
/// 3. very long text → small size, the ring takes what is left (≥ minimum), the text the rest.
struct CounterLayoutTests {
    // iPhone 17-like values: 402 pt wide, ~660 pt between the toolbar and the previous/next bar.
    private let width: CGFloat = 402
    private let height: CGFloat = 660
    private let stats: CGFloat = 80
    private let line: CGFloat = 40
    private let smallLine: CGFloat = 25

    /// Text + ring space on that screen: 660 - 28 - 80 - 32 = 520.
    private var room: CGFloat { height - CounterLayout.textTopPadding - stats - 2 * CounterLayout.ringVerticalPadding }
    private var ringMax: CGFloat { CounterLayout.maximumRing(width: width) }   // 330

    private func layout(height: CGFloat? = nil, width: CGFloat? = nil, stats: CGFloat? = nil,
                        normal: CGFloat, small: CGFloat, smallLine: CGFloat? = nil) -> CounterLayout.Result {
        CounterLayout.layout(availableHeight: height ?? self.height, width: width ?? self.width,
                             statsHeight: stats ?? self.stats, normalTextHeight: normal, smallTextHeight: small,
                             smallLineHeight: smallLine ?? self.smallLine)
    }

    private func used(_ result: CounterLayout.Result, stats: CGFloat) -> CGFloat {
        CounterLayout.textTopPadding + result.textHeight + stats + 2 * CounterLayout.ringVerticalPadding
            + result.ringDiameter
    }

    // MARK: Step 1: normal text

    @Test func shortTextGetsTheBiggestRing() {
        let result = layout(normal: line, small: smallLine)
        #expect(result == .init(textHeight: line, ringDiameter: ringMax, usesSmallText: false))
    }

    // MARK: Step 2: long text, user's size, smaller ring

    @Test func longTextKeepsTheUserSizeAndTheRingShrinks() {
        let text: CGFloat = 230   // 230 + 330 > 520, but 230 + 240 <= 520
        let result = layout(normal: text, small: 100)
        #expect(result.usesSmallText == false)
        #expect(result.textHeight == text)
        #expect(result.ringDiameter == room - text)   // 290
        #expect(result.ringDiameter > CounterLayout.ringMinimum && result.ringDiameter < ringMax)
    }

    @Test func exactlyAtTheMinimumRingStillUsesTheUserSize() {
        let text = room - CounterLayout.ringMinimum   // 280
        let result = layout(normal: text, small: 100)
        #expect(result == .init(textHeight: text, ringDiameter: CounterLayout.ringMinimum, usesSmallText: false))
    }

    // MARK: Step 3: very long text, small size

    @Test func oneLineMoreSwitchesToTheSmallSize() {
        let result = layout(normal: room - CounterLayout.ringMinimum + 1, small: 120)
        #expect(result.usesSmallText)
        #expect(result.textHeight == 120)                 // the whole small text fits
        #expect(result.ringDiameter == min(ringMax, room - 120))
    }

    @Test func smallTextThatFitsLetsTheRingGrowBack() {
        // 520 - 250 = 270: between the minimum and the maximum.
        #expect(layout(normal: 900, small: 250) == .init(textHeight: 250, ringDiameter: 270, usesSmallText: true))
        // 520 - 150 = 370: capped at the biggest ring.
        #expect(layout(normal: 900, small: 150) == .init(textHeight: 150, ringDiameter: ringMax, usesSmallText: true))
    }

    @Test func textLongerThanTheScreenScrollsWithTheMinimumRing() {
        let result = layout(normal: 2_000, small: 900)
        #expect(result.usesSmallText)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
        #expect(result.textHeight == room - CounterLayout.ringMinimum)   // the window takes all the rest
        #expect(used(result, stats: stats) == height)
    }

    @Test func aSmallUserFontIsNeverEnlarged() {
        // Font size 14 (< 16): normal and small are the same text height.
        let result = layout(normal: 600, small: 600)
        #expect(result.usesSmallText)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
    }

    // MARK: Real iPhones, biggest font + "today" row (measured: stats ≈ 214 pt, a line ≈ 61 pt)

    @Test(arguments: [(375, 812), (390, 844), (402, 874), (440, 956)] as [(CGFloat, CGFloat)])
    func faceIDiPhonesKeepTheMinimumRingWithAyatAlKursi(width: CGFloat, screenHeight: CGFloat) {
        let available = screenHeight - 116 - 60 - 34   // toolbar + status bar, buttons, home bar
        let result = layout(height: available, width: width, stats: 214, normal: 61 * 12, small: 25 * 10)
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(result.textHeight >= 25)
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    @Test func iPhoneSEWithBiggestFontAndTodayRowKeepsTheMinimumRing() {
        let available: CGFloat = 667 - 64 - 60   // status bar + toolbar, buttons (no home bar)
        let result = layout(height: available, width: 375, stats: 214, normal: 61 * 3, small: 25 * 3, smallLine: 25)
        #expect(result.usesSmallText)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
        #expect(result.textHeight >= 25)   // at least one line, the rest scrolls
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    @Test func zoomedSmallScreenShrinksTheRingInsteadOfOverflowing() {
        // iPhone SE with Display Zoom (320 x 568 pt), biggest font, "today" row.
        let available: CGFloat = 568 - 64 - 60
        let result = layout(height: available, width: 320, stats: 214, normal: 61 * 3, small: 25 * 3, smallLine: 25)
        #expect(result.textHeight == 25)
        #expect(result.ringDiameter > 100 && result.ringDiameter < CounterLayout.ringMinimum)
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    // MARK: Never overflows

    @Test(arguments: [420, 520, 640, 760, 900] as [CGFloat])
    func everythingAlwaysFits(availableHeight: CGFloat) {
        for normal in stride(from: CGFloat(30), through: 1_200, by: 70) {
            let small = (normal * 0.45).rounded()
            let result = layout(height: availableHeight, normal: normal, small: small)
            #expect(used(result, stats: stats) <= availableHeight + 0.5, "normal \(normal)")
            #expect(result.ringDiameter <= ringMax)
            if !result.usesSmallText { #expect(result.textHeight == normal) }
        }
    }

    @Test func narrowScreenRingFitsTheWidth() {
        let narrow: CGFloat = 320
        #expect(CounterLayout.maximumRing(width: narrow) == narrow - 72)
        let result = layout(width: narrow, normal: line, small: smallLine)
        #expect(result.ringDiameter == narrow - 72)
    }
}
