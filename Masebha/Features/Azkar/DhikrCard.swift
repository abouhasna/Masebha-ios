import SwiftUI

/// One card of the Azkar list (≈ custom_cardview.xml).
struct DhikrCard: View {
    let dhikr: Dhikr
    let palette: ThemePalette
    let now: Date
    let onEdit: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dhikr.name)
                    .appFont(25, .medium, relativeTo: .title2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("card.name")
                Text(NumberText.grouped(dhikr.total))
                    .appFont(14, .regular)
                    .opacity(0.9)
                    .accessibilityIdentifier("card.total")
            }
            VStack(spacing: 0) {
                Text(lastOpenedText)
                    .appFont(12, .light)
                    .opacity(0.75)
                    .lineLimit(1)
                    .accessibilityIdentifier("card.lastOpened")
                Menu {
                    Button(tr("common.edit"), systemImage: "pencil", action: onEdit)
                    Button(tr("common.reset"), systemImage: "arrow.counterclockwise", action: onReset)
                    Button(tr("common.delete"), systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .rotationEffect(.degrees(90))
                        .frame(width: 44, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(tr("card.menu"))
                .accessibilityIdentifier("card.menu")
            }
            .fixedSize()
        }
        .foregroundStyle(Color(argb: palette.text))
        .padding(.vertical, 11)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(argb: palette.card))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card")
    }

    private var lastOpenedText: String {
        switch LastOpened.describe(dhikr.lastOpenedAt, now: now) {
        case .never: tr("card.opened.never")
        case .justNow: tr("card.opened.recent")
        case .today(let time): tr("card.opened.today", time)
        case .yesterday(let time): tr("card.opened.yesterday", time)
        case .date(let date): date
        }
    }
}
