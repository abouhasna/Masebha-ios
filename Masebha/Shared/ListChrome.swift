import SwiftUI

/// The floating "+" of the Azkar and Wird lists, in the toolbar colors.
struct FloatingAddButton: View {
    let palette: ThemePalette
    let label: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools)))
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(argb: palette.tools)))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

/// Under the toolbar, in its colors, while a list's reorder mode is on: the hint and "Done".
/// "Done" is here rather than in the toolbar: iOS 26 drew it there as a pale glass capsule with
/// white text on some themes. Here its contrast is ours to guarantee.
struct ReorderBar: View {
    let palette: ThemePalette
    let onDone: () -> Void

    var body: some View {
        let color = Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools))
        HStack(spacing: 12) {
            Text(tr("list.reorder.hint"))
                .appFont(14, .medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("list.reorderHint")
            Button(action: onDone) {
                Text(tr("common.done"))
                    .appFont(16, .bold)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(color.opacity(0.18)))
                    .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("list.doneReordering")
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(argb: palette.tools))
    }
}

/// The ≡ shown on a card in reorder mode, in the card's text color (visible on every theme).
struct ReorderHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 22, weight: .bold))
            .frame(width: 44, height: 40)
            .accessibilityLabel(tr("card.reorder"))
            .accessibilityIdentifier("card.handle")
    }
}
