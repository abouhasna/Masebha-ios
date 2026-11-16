import SwiftUI
import UIKit

/// The middle of the counter screen: dhikr text, statistics and the progress ring.
///
/// Fonts here have fixed sizes (the "Font size" setting controls them, like Android), so the
/// layout can be computed exactly: see `CounterLayout`.
struct CounterBody: View {
    let model: CounterModel
    let palette: ThemePalette
    let settings: AppSettings
    @Environment(\.appFontFamily) private var family

    private static let smallTextSize: CGFloat = 16   // Android ZEKER_SMALL_SP
    private static let statsTopPadding: CGFloat = 24
    private static let statsRowSpacing: CGFloat = 14
    private static let labelValueSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let textWidth = width - 32
            let text = textFont(textWidth: textWidth)
            if settings.scrollableText {
                let layout = CounterLayout.scrolling(
                    availableHeight: geometry.size.height, width: width, statsHeight: statsHeight,
                    textHeight: TextMeasure.height(model.dhikr.name, font: text, width: textWidth) + 4,
                    lineHeight: text.lineHeight)
                VStack(spacing: 0) {
                    ScrollView(.vertical) { dhikrLabel(size: text.pointSize) }
                        .frame(height: layout.textWindowHeight)
                        .scrollBounceBehavior(.basedOnSize)
                        .padding(.horizontal, 16)
                        .padding(.top, CounterLayout.textTopPadding)
                        .accessibilityIdentifier("counter.textWindow")
                    statistics
                    Spacer(minLength: CounterLayout.ringVerticalPadding)
                    ring(diameter: layout.ringDiameter)
                    Spacer(minLength: CounterLayout.ringVerticalPadding)
                }
            } else {
                // The text is shown in full; the ring keeps its full size and the page scrolls.
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        dhikrLabel(size: text.pointSize)
                            .padding(.horizontal, 16)
                            .padding(.top, CounterLayout.textTopPadding)
                        statistics
                        Spacer(minLength: CounterLayout.ringVerticalPadding)
                        ring(diameter: CounterLayout.maximumRing(width: width))
                        Spacer(minLength: CounterLayout.ringVerticalPadding)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("counter.page")
            }
        }
    }

    // MARK: Sizes (same formulas as Android applyFontSizes)

    private var fontSize: CGFloat { CGFloat(settings.fontSize) }
    private var labelSize: CGFloat { max(12, fontSize - 16) }
    private var valueSize: CGFloat { max(16, fontSize - 12) }
    private var currentSize: CGFloat { max(44, fontSize * 3 - 6) }

    /// The dhikr font: the chosen size, or 16 pt when the text would need more than 4 lines.
    private func textFont(textWidth: CGFloat) -> UIFont {
        let name = family.postScriptName(.light)
        let normal = UIFont(name: name, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let shrinks = fontSize > Self.smallTextSize
            && TextMeasure.lineCount(model.dhikr.name, font: normal, width: textWidth) > Int(CounterLayout.maxTextLines)
        let size = shrinks ? Self.smallTextSize : fontSize
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    /// Height of the statistics block, from the font metrics (matches the layout below).
    private var statsHeight: CGFloat {
        let label = UIFont(name: family.postScriptName(.regular), size: labelSize) ?? .systemFont(ofSize: labelSize)
        let value = UIFont(name: family.postScriptName(.medium), size: valueSize) ?? .systemFont(ofSize: valueSize)
        let row = label.lineHeight + Self.labelValueSpacing + value.lineHeight
        let rows: CGFloat = settings.showTodayCount ? 2 : 1
        return Self.statsTopPadding + rows * row + (rows - 1) * Self.statsRowSpacing
    }

    // MARK: Parts

    private func dhikrLabel(size: CGFloat) -> some View {
        Text(model.dhikr.name)
            .font(.custom(family.postScriptName(.light), fixedSize: size))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Color(argb: palette.counterText))
            .accessibilityIdentifier("counter.dhikrText")
    }

    private var statistics: some View {
        let state = model.state
        return VStack(spacing: Self.statsRowSpacing) {
            HStack(spacing: 0) {
                stat(tr("counter.total"), NumberText.grouped(state.total), id: "counter.total")
                stat(tr("counter.loops"), NumberText.grouped(state.loops), id: "counter.loops")
            }
            if settings.showTodayCount {
                HStack(spacing: 0) {
                    stat(tr("counter.today"), NumberText.grouped(state.today), id: "counter.today")
                    stat(tr("counter.session"), NumberText.grouped(state.session), id: "counter.session")
                }
            }
        }
        .foregroundStyle(Color(argb: palette.counterText))
        .padding(.top, Self.statsTopPadding)
    }

    private func stat(_ label: String, _ value: String, id: String) -> some View {
        VStack(spacing: Self.labelValueSpacing) {
            Text(label)
                .font(.custom(family.postScriptName(.regular), fixedSize: labelSize))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.custom(family.postScriptName(.medium), fixedSize: valueSize))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity)
    }

    private func ring(diameter: CGFloat) -> some View {
        ProgressRing(current: model.state.current, loopSize: model.state.loopSize, palette: palette,
                     numberSize: currentSize)
            .frame(width: diameter, height: diameter)
            .accessibilityIdentifier("counter.ring")
    }
}

/// The circular progress of the current loop with the count in the middle.
struct ProgressRing: View {
    let current: Int
    let loopSize: Int
    let palette: ThemePalette
    let numberSize: CGFloat
    @Environment(\.appFontFamily) private var family

    var body: some View {
        let progress = loopSize > 0 ? Double(current) / Double(loopSize) : 0
        ZStack {
            Circle()
                .stroke(Color(argb: palette.ringTrack), lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color(argb: palette.ring), style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                .rotationEffect(.degrees(-90))   // starts at the top, fills clockwise
                .animation(current == 0 ? nil : .easeOut(duration: 0.12), value: current)
            Circle()
                .fill(Color(argb: palette.progressButton))
                .padding(9)
            Text(NumberText.grouped(current))
                .font(.custom(family.postScriptName(.extraLight), fixedSize: numberSize))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .foregroundStyle(Color(argb: palette.progressText))
                .padding(28)
                .accessibilityIdentifier("counter.current")
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

    static func lineCount(_ text: String, font: UIFont, width: CGFloat) -> Int {
        guard font.lineHeight > 0 else { return 1 }
        return Int((height(text, font: font, width: width) / font.lineHeight).rounded())
    }
}
