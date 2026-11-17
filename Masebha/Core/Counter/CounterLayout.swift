import CoreGraphics

/// Sizes on the counter and wird screens: the dhikr text and the progress ring (pure math,
/// unit-tested). The text has priority (owner's rule):
///
/// 1. Normal text: the whole text at the user's size with the biggest ring.
/// 2. Long text: still the whole text at the user's size; the ring shrinks, down to its minimum.
/// 3. Very long text: the small size (16 pt). The ring takes what is left between its minimum and
///    maximum, the text gets all the rest and scrolls inside it if it is still longer.
///
/// Only on an extremely short screen (a small iPhone with Display Zoom, the biggest font and the
/// "today" row) can the ring go below its minimum, so that one line of text stays visible.
nonisolated enum CounterLayout {
    static let ringMaximum: CGFloat = 340
    static let ringMinimum: CGFloat = 240
    static let ringSideMargin: CGFloat = 36
    static let ringVerticalPadding: CGFloat = 16
    static let textTopPadding: CGFloat = 28
    /// The small text size of step 3 (Android ZEKER_SMALL_SP); never larger than the user's size.
    static let smallTextSize: CGFloat = 16

    struct Result: Equatable {
        /// Height of the text window (the text scrolls inside it if it is taller).
        let textHeight: CGFloat
        let ringDiameter: CGFloat
        let usesSmallText: Bool
    }

    /// Largest ring for this screen width.
    static func maximumRing(width: CGFloat) -> CGFloat {
        min(ringMaximum, max(0, width - 2 * ringSideMargin))
    }

    /// Text heights are measured with the font actually used, at the user's size and at the small size.
    static func layout(availableHeight: CGFloat, width: CGFloat, statsHeight: CGFloat,
                       normalTextHeight: CGFloat, smallTextHeight: CGFloat, smallLineHeight: CGFloat) -> Result {
        let ringMax = maximumRing(width: width)
        let ringMin = min(ringMinimum, ringMax)
        let room = availableHeight - textTopPadding - statsHeight - 2 * ringVerticalPadding   // text + ring

        // Steps 1 and 2: the whole text at the user's size, the ring as big as the rest allows.
        if normalTextHeight + ringMin <= room {
            return Result(textHeight: normalTextHeight, ringDiameter: min(ringMax, room - normalTextHeight),
                          usesSmallText: false)
        }

        // Step 3: the small size. The ring takes what the text leaves (within its limits).
        let ring = min(ringMax, max(ringMin, room - smallTextHeight))
        let text = min(smallTextHeight, room - ring)
        let oneLine = min(smallTextHeight, smallLineHeight)
        if text >= oneLine {
            return Result(textHeight: text, ringDiameter: ring, usesSmallText: true)
        }
        // Very short screen: one line of text stays visible, the ring gives way.
        return Result(textHeight: oneLine, ringDiameter: max(0, min(ringMax, room - oneLine)), usesSmallText: true)
    }
}
