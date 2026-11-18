import CoreGraphics
import Testing
@testable import Masebha

/// The counter / wird layout rule (owner's requirement): the text has priority.
/// The ring shrinks first (down to its minimum); then the font gets one point smaller at a time;
/// only when even 16 pt does not fit does the text scroll in its window.
struct CounterLayoutTests {
    // iPhone 17-like values: 402 pt wide, ~660 pt between the toolbar and the previous/next bar.
    private let width: CGFloat = 402
    private let height: CGFloat = 660
    private let stats: CGFloat = 80

    /// Text + ring space on that screen: 660 - 28 - 80 - 32 = 520.
    private var room: CGFloat { height - CounterLayout.textTopPadding - stats - 2 * CounterLayout.ringVerticalPadding }
    private var ringMax: CGFloat { CounterLayout.maximumRing(width: width) }   // 330

    /// Lays out a text whose height at each size is given by `textHeight` (line height 25 pt).
    private func layout(height: CGFloat? = nil, width: CGFloat? = nil, stats: CGFloat? = nil,
                        sizes: [CGFloat] = CounterLayout.candidateSizes(from: 30), lineHeight: CGFloat = 25,
                        textHeight: (CGFloat) -> CGFloat) -> CounterLayout.Result {
        CounterLayout.layout(availableHeight: height ?? self.height, width: width ?? self.width,
                             statsHeight: stats ?? self.stats, sizes: sizes) { size in
            .init(fontSize: size, height: textHeight(size), lineHeight: lineHeight)
        }
    }

    private func used(_ result: CounterLayout.Result, stats: CGFloat) -> CGFloat {
        CounterLayout.textTopPadding + result.textHeight + stats + 2 * CounterLayout.ringVerticalPadding
            + result.ringDiameter
    }

    @Test func candidateSizesGoDownOnePointAtATime() {
        #expect(CounterLayout.candidateSizes(from: 20) == [20, 19, 18, 17, 16])
        #expect(CounterLayout.candidateSizes(from: 16) == [16])
        #expect(CounterLayout.candidateSizes(from: 14) == [14])   // never larger than the user's size
        #expect(CounterLayout.candidateSizes(from: 42).count == 27)
    }

    // MARK: The rule, step by step

    @Test func shortTextGetsTheBiggestRingAtTheUserSize() {
        let result = layout { _ in 40 }
        #expect(result == .init(textHeight: 40, ringDiameter: ringMax, fontSize: 30))
    }

    @Test func longTextKeepsTheUserSizeAndTheRingShrinks() {
        let result = layout { _ in 230 }   // 230 + 330 > 520, but 230 + 240 <= 520
        #expect(result == .init(textHeight: 230, ringDiameter: 290, fontSize: 30))
    }

    @Test func exactlyAtTheMinimumRingStillUsesTheUserSize() {
        let text = room - CounterLayout.ringMinimum   // 280
        #expect(layout { _ in text } == .init(textHeight: text, ringDiameter: CounterLayout.ringMinimum, fontSize: 30))
    }

    @Test func aLittleSmallerFontIsTriedBeforeTheSmallSize() {
        // Height grows with the square of the size: 30 pt → 360, 27 pt → 291.6, 26 pt → 270.4.
        let result = layout { size in 0.4 * size * size }
        #expect(result.fontSize == 26)                   // the largest size that fits with the minimum ring
        #expect(abs(result.textHeight - 270.4) < 0.01)
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(used(result, stats: stats) <= height + 0.5)
    }

    @Test func onlyWhatIsNeededIsMeasured() {
        var measured: [CGFloat] = []
        _ = layout { size in
            measured.append(size)
            return 0.4 * size * size
        }
        #expect(measured == [30, 29, 28, 27, 26])   // stops at the first size that fits
    }

    @Test func textLongerThanTheScreenUsesTheSmallSizeAndScrolls() {
        let result = layout { size in size * 40 }   // 16 pt → 640: never fits
        #expect(result.fontSize == 16)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
        #expect(result.textHeight == room - CounterLayout.ringMinimum)   // the window takes all the rest
        #expect(used(result, stats: stats) == height)
    }

    @Test func smallTextThatFitsLetsTheRingGrowBack() {
        // Only 16 pt fits, and it leaves more than the minimum for the ring.
        let result = layout { size in size == 16 ? 250 : 400 }
        #expect(result == .init(textHeight: 250, ringDiameter: 270, fontSize: 16))
    }

    @Test func aSmallUserFontIsNeverEnlarged() {
        let result = layout(sizes: CounterLayout.candidateSizes(from: 14)) { _ in 600 }
        #expect(result.fontSize == 14)
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
    }

    // MARK: Real iPhones, biggest font + "today" row (measured: stats ≈ 214 pt, a 42 pt line ≈ 61 pt)

    @Test(arguments: [(375, 812), (390, 844), (402, 874), (440, 956)] as [(CGFloat, CGFloat)])
    func faceIDiPhonesKeepTheMinimumRingWithAyatAlKursi(width: CGFloat, screenHeight: CGFloat) {
        let available = screenHeight - 116 - 60 - 34   // toolbar + status bar, buttons, home bar
        let result = layout(height: available, width: width, stats: 214,
                            sizes: CounterLayout.candidateSizes(from: 42)) { size in size * size * 0.45 * 4 }
        #expect(result.ringDiameter >= CounterLayout.ringMinimum)
        #expect(result.textHeight >= 25)
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    @Test func iPhoneSEWithBiggestFontAndTodayRowKeepsTheMinimumRing() {
        let available: CGFloat = 667 - 64 - 60   // status bar + toolbar, buttons (no home bar)
        let result = layout(height: available, width: 375, stats: 214,
                            sizes: CounterLayout.candidateSizes(from: 42)) { size in size * 4.5 }
        #expect(result.ringDiameter == CounterLayout.ringMinimum)
        #expect(result.textHeight >= 25)
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    @Test func zoomedSmallScreenShrinksTheRingInsteadOfOverflowing() {
        // iPhone SE with Display Zoom (320 x 568 pt), biggest font, "today" row.
        let available: CGFloat = 568 - 64 - 60
        let result = layout(height: available, width: 320, stats: 214,
                            sizes: CounterLayout.candidateSizes(from: 42)) { size in size * 4.5 }
        #expect(result.textHeight == 25)
        #expect(result.ringDiameter > 100 && result.ringDiameter < CounterLayout.ringMinimum)
        #expect(used(result, stats: 214) <= available + 0.5)
    }

    // MARK: Never overflows

    @Test(arguments: [420, 520, 640, 760, 900] as [CGFloat])
    func everythingAlwaysFits(availableHeight: CGFloat) {
        for factor in stride(from: CGFloat(0.5), through: 40, by: 1.5) {
            let result = layout(height: availableHeight) { size in factor * size }
            #expect(used(result, stats: stats) <= availableHeight + 0.5, "factor \(factor)")
            #expect(result.ringDiameter <= ringMax)
            #expect((16...30).contains(result.fontSize))
        }
    }

    @Test func narrowScreenRingFitsTheWidth() {
        let narrow: CGFloat = 320
        #expect(CounterLayout.maximumRing(width: narrow) == narrow - 72)
        #expect(layout(width: narrow) { _ in 40 }.ringDiameter == narrow - 72)
    }
}
