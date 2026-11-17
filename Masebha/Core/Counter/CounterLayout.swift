import CoreGraphics

/// Sizes on the counter screen: the dhikr text window and the progress ring (pure math, unit-tested).
///
/// "Scroll long dhikr" on: the text window shows at most 4 lines, and it is never so tall that
/// the ring would drop under its minimum size. The text scrolls inside the window.
/// "Scroll long dhikr" off: the text is shown in full and the ring keeps its full size;
/// the whole page scrolls instead.
nonisolated enum CounterLayout {
    static let ringMaximum: CGFloat = 340
    static let ringMinimum: CGFloat = 240
    static let ringSideMargin: CGFloat = 36
    static let ringVerticalPadding: CGFloat = 16
    static let textTopPadding: CGFloat = 28
    static let maxTextLines: CGFloat = 4

    struct Result: Equatable {
        let textWindowHeight: CGFloat
        let ringDiameter: CGFloat
    }

    /// Largest ring for this screen width (never wider than the screen allows).
    static func maximumRing(width: CGFloat) -> CGFloat {
        min(ringMaximum, max(0, width - 2 * ringSideMargin))
    }

    /// Scroll mode. `textHeight` and `lineHeight` are measured with the font actually used.
    static func scrolling(availableHeight: CGFloat, width: CGFloat, statsHeight: CGFloat,
                          textHeight: CGFloat, lineHeight: CGFloat) -> Result {
        let ringMax = maximumRing(width: width)
        let ringMin = min(ringMinimum, ringMax)
        let fixed = textTopPadding + statsHeight + 2 * ringVerticalPadding

        // The text gets what is left after the minimum ring, up to 4 lines (at least 1 line).
        let roomForText = availableHeight - fixed - ringMin
        let fourLines = lineHeight * maxTextLines
        let oneLine = min(textHeight, lineHeight)
        let window = max(oneLine, min(textHeight, fourLines, roomForText))

        // The ring takes the rest, up to its maximum. Because the window gave way first, the rest
        // is at least the minimum ring, except on a very short screen (the 4.7" iPhone SE with the
        // biggest font and the "today" row on, or a zoomed display): there the ring shrinks to
        // fit, so it never slips under the previous/next buttons.
        let roomForRing = availableHeight - fixed - window
        let ring = max(0, min(ringMax, roomForRing))
        return Result(textWindowHeight: window, ringDiameter: ring)
    }
}
