import SwiftUI
import UIKit

/// The middle of the counter and wird screens: the dhikr text on top, a statistics block, and
/// the progress ring, sized by `CounterLayout` (the text has priority).
///
/// Fonts have fixed sizes (the "Font size" setting controls them, like Android), so the layout
/// can be computed exactly. Taps are handled by the screen around it; a swipe on the text only
/// scrolls it.
struct DhikrStage<Stats: View, Ring: View>: View {
    let text: String
    let fontSize: CGFloat
    let textColor: ARGB
    /// Exact height of `stats`, from font metrics.
    let statsHeight: CGFloat
    let stats: Stats
    let ring: Ring
    @Environment(\.appFontFamily) private var family

    init(text: String, fontSize: CGFloat, textColor: ARGB, statsHeight: CGFloat,
         @ViewBuilder stats: () -> Stats, @ViewBuilder ring: () -> Ring) {
        self.text = text
        self.fontSize = fontSize
        self.textColor = textColor
        self.statsHeight = statsHeight
        self.stats = stats()
        self.ring = ring()
    }

    var body: some View {
        GeometryReader { geometry in
            let textWidth = geometry.size.width - 32
            let normal = uiFont(fontSize)
            let small = uiFont(min(fontSize, CounterLayout.smallTextSize))
            let layout = CounterLayout.layout(
                availableHeight: geometry.size.height, width: geometry.size.width, statsHeight: statsHeight,
                normalTextHeight: TextMeasure.height(text, font: normal, width: textWidth) + 4,
                smallTextHeight: TextMeasure.height(text, font: small, width: textWidth) + 4,
                smallLineHeight: small.lineHeight)
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    Text(text)
                        .font(.custom(family.postScriptName(.light),
                                      fixedSize: layout.usesSmallText ? small.pointSize : normal.pointSize))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color(argb: textColor))
                        .accessibilityIdentifier("counter.dhikrText")
                }
                .frame(height: layout.textHeight)
                .scrollBounceBehavior(.basedOnSize)
                .padding(.horizontal, 16)
                .padding(.top, CounterLayout.textTopPadding)
                // A container with its own id: the text inside keeps "counter.dhikrText".
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("counter.textWindow")
                stats
                    .frame(height: statsHeight, alignment: .top)
                Spacer(minLength: CounterLayout.ringVerticalPadding)
                ring
                    .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                Spacer(minLength: CounterLayout.ringVerticalPadding)
            }
        }
    }

    private func uiFont(_ size: CGFloat) -> UIFont {
        UIFont(name: family.postScriptName(.light), size: size) ?? .systemFont(ofSize: size)
    }
}

/// The circular progress with a number in the middle (and an optional small detail under it).
struct ProgressRing: View {
    /// 0…1
    let progress: Double
    let number: String
    var detail: String?
    let palette: ThemePalette
    let numberSize: CGFloat
    @Environment(\.appFontFamily) private var family

    private static let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(argb: palette.ringTrack), lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Color(argb: palette.ring), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))   // starts at the top, fills clockwise
                .animation(progress == 0 ? nil : .easeOut(duration: 0.12), value: progress)
            // The center circle reaches the ring's inner edge (no gap; the ring is drawn on the
            // circle's edge, half of its width inside).
            Circle()
                .fill(Color(argb: palette.progressButton))
                .padding(Self.lineWidth / 2 - 0.5)
            VStack(spacing: 0) {
                Text(number)
                    .font(.custom(family.postScriptName(.extraLight), fixedSize: numberSize))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .accessibilityIdentifier("counter.current")
                if let detail {
                    Text(detail)
                        .font(.custom(family.postScriptName(.regular), fixedSize: max(14, numberSize / 3.2)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .opacity(0.8)
                        .accessibilityIdentifier("counter.target")
                }
            }
            .foregroundStyle(Color(argb: palette.progressText))
            .padding(28)
        }
        // The ring always starts at the top and fills clockwise, in Arabic too (SwiftUI would
        // otherwise mirror the rotation in right-to-left mode).
        .environment(\.layoutDirection, .leftToRight)
    }
}

enum TextMeasure {
    static func height(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        return ceil(rect.height)
    }
}
