import SwiftUI
import UIKit

/// The middle of the counter screen: dhikr text, statistics and the progress ring
/// (laid out by `DhikrStage`, text first).
struct CounterBody: View {
    let model: CounterModel
    let palette: ThemePalette
    let settings: AppSettings
    @Environment(\.appFontFamily) private var family

    private static let statsTopPadding: CGFloat = 24
    private static let statsRowSpacing: CGFloat = 14
    private static let labelValueSpacing: CGFloat = 4

    var body: some View {
        let state = model.state
        DhikrStage(text: model.dhikr.name, fontSize: fontSize, textColor: palette.counterText,
                   statsHeight: statsHeight) {
            statistics
        } ring: {
            ProgressRing(progress: state.loopSize > 0 ? Double(state.current) / Double(state.loopSize) : 0,
                         number: NumberText.grouped(state.current), palette: palette, numberSize: currentSize)
        }
    }

    // MARK: Sizes (same formulas as Android applyFontSizes)

    private var fontSize: CGFloat { CGFloat(settings.fontSize) }
    private var labelSize: CGFloat { max(12, fontSize - 16) }
    private var valueSize: CGFloat { max(16, fontSize - 12) }
    private var currentSize: CGFloat { max(44, fontSize * 3 - 6) }

    /// Height of the statistics block, from the font metrics (matches the layout below).
    private var statsHeight: CGFloat {
        let label = UIFont(name: family.postScriptName(.regular), size: labelSize) ?? .systemFont(ofSize: labelSize)
        let value = UIFont(name: family.postScriptName(.medium), size: valueSize) ?? .systemFont(ofSize: valueSize)
        let row = label.lineHeight + Self.labelValueSpacing + value.lineHeight
        let rows: CGFloat = settings.showTodayCount ? 2 : 1
        return Self.statsTopPadding + rows * row + (rows - 1) * Self.statsRowSpacing
    }

    // MARK: Parts

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
}
