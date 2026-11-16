import SwiftUI
import UIKit

/// The middle of the counter screen: dhikr text, statistics and the progress ring.
struct CounterBody: View {
    let model: CounterModel
    let palette: ThemePalette
    let settings: AppSettings
    @Environment(\.appFontFamily) private var family

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            if settings.scrollableText {
                // Long text scrolls inside a 4-line box above the counter (Android default).
                VStack(spacing: 0) {
                    dhikrText(width: width, scrollable: true)
                    statistics
                    // The ring takes the space that is left, so it never overlaps the buttons below.
                    GeometryReader { space in
                        ring(diameter: max(120, min(space.size.width - 72, space.size.height - 32, 340)))
                            .frame(width: space.size.width, height: space.size.height)
                    }
                }
            } else {
                // The whole content scrolls instead.
                ScrollView {
                    VStack(spacing: 0) {
                        dhikrText(width: width, scrollable: false)
                        statistics
                        ring(diameter: min(width - 72, 340))
                            .padding(.vertical, 28)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var sizes: (label: CGFloat, value: CGFloat, current: CGFloat, text: CGFloat) {
        let size = CGFloat(settings.fontSize)  // same formulas as Android applyFontSizes
        return (max(12, size - 16), max(16, size - 12), max(44, size * 3 - 6), size)
    }

    private func dhikrText(width: CGFloat, scrollable: Bool) -> some View {
        DhikrTextBlock(text: model.dhikr.name, fontName: family.postScriptName(.light),
                       normalSize: sizes.text, width: width - 32, scrollable: scrollable)
            .foregroundStyle(Color(argb: palette.counterText))
            .padding(.horizontal, 16)
            .padding(.top, 28)
    }

    private var statistics: some View {
        let state = model.state
        return VStack(spacing: 14) {
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
        .padding(.top, 24)
    }

    private func stat(_ label: String, _ value: String, id: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .appFont(sizes.label, .regular)
            Text(value)
                .appFont(sizes.value, .medium)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity)
    }

    private func ring(diameter: CGFloat) -> some View {
        ProgressRing(current: model.state.current, loopSize: model.state.loopSize, palette: palette,
                     numberSize: sizes.current)
            .frame(width: diameter, height: diameter)
    }
}

/// The circular progress of the current loop with the count in the middle.
struct ProgressRing: View {
    let current: Int
    let loopSize: Int
    let palette: ThemePalette
    let numberSize: CGFloat

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
                .appFont(numberSize, .extraLight, relativeTo: .largeTitle)
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

/// The dhikr text. Above 4 lines it shrinks to 16 pt (Android rule); in "scroll" mode the box is
/// limited to 4 lines and scrolls.
struct DhikrTextBlock: View {
    let text: String
    let fontName: String
    let normalSize: CGFloat
    let width: CGFloat
    let scrollable: Bool

    private static let smallSize: CGFloat = 16
    private static let maxLines = 4

    var body: some View {
        let normalFont = UIFont(name: fontName, size: normalSize) ?? .systemFont(ofSize: normalSize)
        let shrinks = normalSize > Self.smallSize
            && TextMeasure.lineCount(text, font: normalFont, width: width) > Self.maxLines
        let size = shrinks ? Self.smallSize : normalSize
        let font = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        let label = Text(text)
            .font(.custom(fontName, fixedSize: size))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("counter.dhikrText")

        if scrollable {
            let fullHeight = TextMeasure.height(text, font: font, width: width) + 4
            let maxHeight = font.lineHeight * CGFloat(Self.maxLines) + 4
            ScrollView(.vertical) { label }
                .frame(height: min(fullHeight, maxHeight))
                .scrollBounceBehavior(.basedOnSize)
        } else {
            label
        }
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
