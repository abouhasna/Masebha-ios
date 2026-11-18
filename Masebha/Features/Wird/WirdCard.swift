import SwiftUI

/// One wird on the list (≈ WirdAdapter): name, number of azkar (or progress), today's status.
/// The status chip uses the card's text color with a different icon per state, so it is
/// readable on every theme.
struct WirdCard: View {
    let wird: WirdSummary
    let palette: ThemePalette
    var isReordering = false
    let onEdit: () -> Void
    let onReset: () -> Void
    let onReorder: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(wird.name)
                    .appFont(22, .medium, relativeTo: .title3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("wird.card.name")
                Text(countText)
                    .appFont(14, .regular)
                    .opacity(0.9)
                    .accessibilityIdentifier("wird.card.count")
            }
            VStack(alignment: .trailing, spacing: 4) {
                statusChip
                    .padding(.trailing, 8)
                if isReordering {
                    ReorderHandle()
                } else {
                    Menu {
                        Button(tr("common.edit"), systemImage: "pencil", action: onEdit)
                        Button(tr("common.reset"), systemImage: "arrow.counterclockwise", action: onReset)
                        Button(tr("card.reorder"), systemImage: "arrow.up.arrow.down", action: onReorder)
                        Button(tr("common.delete"), systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .rotationEffect(.degrees(90))
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(tr("card.menu"))
                    .accessibilityIdentifier("wird.card.menu")
                }
            }
            .fixedSize()
        }
        .foregroundStyle(Color(argb: palette.text))
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(argb: palette.card))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wird.card")
    }

    private var countText: String {
        let count = wird.state == .started ? "\(wird.finishedCount)/\(wird.itemCount)" : "\(wird.itemCount)"
        return tr("wird.card.count", count)
    }

    private var statusChip: some View {
        let text = Color(argb: palette.text)
        let (icon, label): (String, String) = switch wird.state {
        case .notStarted: ("circle", tr("wird.status.not_started"))
        case .started: ("circle.lefthalf.filled", tr("wird.status.started"))
        case .done: ("checkmark.circle.fill", tr("wird.status.done"))
        }
        let done = wird.state == .done
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .accessibilityHidden(true)
            Text(label)
                .appFont(12, .medium)
        }
        // "Done" is white on green, clear at a glance on every theme (a light outline keeps it
        // visible on green cards too); the other states use the card's text color.
        .foregroundStyle(done ? Color.white : text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(done ? Color(argb: 0xFF1E_8E3E) : text.opacity(wird.state == .started ? 0.14 : 0)))
        .overlay(Capsule().stroke(done ? Color.white.opacity(0.55) : text.opacity(0.45), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wird.card.status")
    }
}
