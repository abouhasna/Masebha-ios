import SwiftUI

/// The toolbar group of icon buttons on the counter and wird screens (▶ ☾ … ⋮).
struct ActionPill<Content: View>: View {
    let color: Color
    let content: Content

    init(color: Color, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .foregroundStyle(color)
        .padding(.horizontal, 4)
        .background { background }
        // Its own identifier, so the toolbar item does not borrow the first button's one (iOS 26).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("counter.actions")
    }

    /// iOS 26 already draws a glass capsule around toolbar items; earlier versions get ours.
    @ViewBuilder
    private var background: some View {
        if #available(iOS 26.0, *) {
            EmptyView()
        } else {
            Capsule().fill(color.opacity(0.15))
                .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
        }
    }
}

struct PillButton: View {
    let symbol: String
    let label: String
    let id: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}

struct PillDivider: View {
    let color: Color

    var body: some View {
        Rectangle().fill(color.opacity(0.25)).frame(width: 1, height: 18)
    }
}

/// The ⋮ of a pill menu.
struct PillMoreLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 17, weight: .bold))
            .rotationEffect(.degrees(90))
            .frame(width: 40, height: 34)
            .contentShape(Rectangle())
    }
}

/// "Previous" / "Next" at the bottom of the counter and wird screens. A missing button keeps
/// its place (like Android's INVISIBLE), so the bar never moves.
struct PreviousNextBar: View {
    let color: ARGB
    let previousEnabled: Bool
    let nextEnabled: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            button(tr("counter.previous"), enabled: previousEnabled, id: "counter.previous", action: onPrevious)
            button(tr("counter.next"), enabled: nextEnabled, id: "counter.next", action: onNext)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func button(_ title: String, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        let tint = Color(argb: color)
        if enabled {
            Button(action: action) {
                Text(title)
                    .appFont(15, .medium)
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Capsule().fill(tint.opacity(0.12))
                            .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 44)
        }
    }
}
