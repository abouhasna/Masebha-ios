import CoreGraphics

/// Sizes on the counter and wird screens: the dhikr text and the progress ring (pure math,
/// unit-tested). The text has priority (owner's rule):
///
/// 1. Normal text: the whole text at the user's size with the biggest ring.
/// 2. Long text: the whole text at the user's size; the ring shrinks, down to its minimum.
/// 3. Longer text: the font gets one point smaller at a time, until the whole text fits with the
///    minimum ring (or a bigger one, if the smaller text leaves room).
/// 4. Very long text: the small size (16 pt). The ring keeps its minimum, and the text gets all
///    the rest and scrolls inside it.
///
/// Only on an extremely short screen (a small iPhone with Display Zoom, the biggest font and the
/// "today" row) can the ring go below its minimum, so that one line of text stays visible.
nonisolated enum CounterLayout {
    static let ringMaximum: CGFloat = 340
    static let ringMinimum: CGFloat = 240
    static let ringSideMargin: CGFloat = 36
    static let ringVerticalPadding: CGFloat = 16
    static let textTopPadding: CGFloat = 28
    /// The smallest text size (Android ZEKER_SMALL_SP); never larger than the user's size.
    static let smallTextSize: CGFloat = 16

    /// The whole text measured at one font size.
    struct TextFit: Equatable {
        let fontSize: CGFloat
        let height: CGFloat
        let lineHeight: CGFloat
    }

    struct Result: Equatable {
        /// Height of the text window (the text scrolls inside it if it is taller).
        let textHeight: CGFloat
        let ringDiameter: CGFloat
        let fontSize: CGFloat
    }

    /// Largest ring for this screen width.
    static func maximumRing(width: CGFloat) -> CGFloat {
        min(ringMaximum, max(0, width - 2 * ringSideMargin))
    }

    /// The sizes to try: the user's size, then one point smaller at a time, down to the small size.
    static func candidateSizes(from userSize: CGFloat) -> [CGFloat] {
        let smallest = min(userSize, smallTextSize)
        return Array(stride(from: userSize, through: smallest, by: -1))
    }

    /// `measure` gives the whole text's height at a size. It is called from the largest size down
    /// and stops at the first that fits, so short texts are measured once.
    static func layout(availableHeight: CGFloat, width: CGFloat, statsHeight: CGFloat,
                       sizes: [CGFloat], measure: (CGFloat) -> TextFit) -> Result {
        let ringMax = maximumRing(width: width)
        let ringMin = min(ringMinimum, ringMax)
        let room = availableHeight - textTopPadding - statsHeight - 2 * ringVerticalPadding   // text + ring

        // Steps 1–3: the largest size whose whole text fits with at least the minimum ring.
        for size in sizes {
            let fit = measure(size)
            if fit.height + ringMin <= room {
                return Result(textHeight: fit.height, ringDiameter: min(ringMax, room - fit.height), fontSize: size)
            }
        }

        // Step 4: the smallest size; the text scrolls in what the minimum ring leaves.
        guard let smallestSize = sizes.last else {
            return Result(textHeight: 0, ringDiameter: max(0, min(ringMax, room)), fontSize: smallTextSize)
        }
        let smallest = measure(smallestSize)
        let ring = min(ringMax, max(ringMin, room - smallest.height))
        let text = min(smallest.height, room - ring)
        let oneLine = min(smallest.height, smallest.lineHeight)
        if text >= oneLine {
            return Result(textHeight: text, ringDiameter: ring, fontSize: smallestSize)
        }
        // Very short screen: one line of text stays visible, the ring gives way.
        return Result(textHeight: oneLine, ringDiameter: max(0, min(ringMax, room - oneLine)), fontSize: smallestSize)
    }
}
