import SwiftUI

/// The three main sections.
enum AppTab: Hashable {
    case azkar, wird, more
}

/// Azkar | Wird | More (replaces the Android bottom navigation and side drawer).
///
/// The bottom bar is our own `AppTabBar`, not the iOS tab bar: iOS 26 draws its tab bar as
/// see-through glass that takes its colors from whatever is behind it, so the icons became
/// unreadable on some themes. Like on Android, ours is solid, in the theme's toolbar color.
/// Choosing a tab shows that tab's first screen.
struct MainTabView: View {
    @State private var selection: AppTab = .azkar

    var body: some View {
        switch selection {
        case .azkar: AzkarTab(selection: $selection)
        case .wird: WirdPlaceholderView(selection: $selection)
        case .more: MoreTab(selection: $selection)
        }
    }
}

/// Navigation of the Azkar tab: the list, and the counter screen pushed on top of it.
struct AzkarTab: View {
    @Binding var selection: AppTab
    @State private var path: [CounterRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            AzkarListView { id in
                // Replace instead of append: a fast double tap can never open two counter screens.
                if path.isEmpty { path = [CounterRoute(dhikrID: id)] }
            }
            // On the list only: the counter screen has no bottom bar.
            .appTabBar($selection)
            .navigationDestination(for: CounterRoute.self) { route in
                CounterView(dhikrID: route.dhikrID)
            }
        }
    }
}

struct CounterRoute: Hashable {
    let dhikrID: Int64
}

extension View {
    /// Puts the bottom bar under this screen; the screen's content ends above it.
    func appTabBar(_ selection: Binding<AppTab>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(selection: selection)
        }
    }
}

/// The bottom bar, colored like Android's: the toolbar color behind, the toolbar accent on it
/// (switched to white or near-black when the accent would not be readable on that color).
struct AppTabBar: View {
    @Binding var selection: AppTab
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let palette = environment.palette
        let content = Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools))
        HStack(spacing: 0) {
            item(.azkar, title: tr("tab.azkar"), image: Image("TabAzkar"), id: "tab.azkar", color: content)
            item(.wird, title: tr("tab.wird"), image: Image("TabWird"), id: "tab.wird", color: content)
            item(.more, title: tr("tab.more"), image: Image(systemName: "ellipsis.circle.fill"), id: "tab.more",
                 color: content)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background {
            Color(argb: palette.tools)
                .shadow(color: .black.opacity(0.2), radius: 2, y: -1)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Selected: full color, bold label and a soft highlight behind the icon.
    /// Not selected: the same color, slightly faded (Android fades it to 55%; 70% reads better).
    private func item(_ tab: AppTab, title: String, image: Image, id: String, color: Color) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 60, height: 30)
                    .background(Capsule().fill(color.opacity(isSelected ? 0.2 : 0)))
                Text(title)
                    .appFont(12, isSelected ? .bold : .medium, relativeTo: .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(color.opacity(isSelected ? 1 : 0.7))
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
