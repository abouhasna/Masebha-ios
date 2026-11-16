import SwiftUI

/// The bottom tabs: Azkar | Wird | More (replaces the Android bottom navigation and side drawer).
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: Tab = .azkar

    enum Tab: Hashable {
        case azkar, wird, more
    }

    var body: some View {
        let palette = environment.palette
        TabView(selection: $selection) {
            AzkarTab()
                .themedTabBar(palette.tools)
                .tabItem { Label { Text(tr("tab.azkar")) } icon: { Image("TabAzkar") } }
                .tag(Tab.azkar)
                .accessibilityIdentifier("tab.azkar")
            WirdPlaceholderView()
                .themedTabBar(palette.tools)
                .tabItem { Label { Text(tr("tab.wird")) } icon: { Image("TabWird") } }
                .tag(Tab.wird)
            MoreTab()
                .themedTabBar(palette.tools)
                .tabItem { Label(tr("tab.more"), systemImage: "ellipsis.circle.fill") }
                .tag(Tab.more)
        }
        .tint(Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools)))
    }
}

/// Navigation of the Azkar tab: the list, and the counter screen pushed on top of it.
struct AzkarTab: View {
    @State private var path: [CounterRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            AzkarListView { id in
                // Replace instead of append: a fast double tap can never open two counter screens.
                if path.isEmpty { path = [CounterRoute(dhikrID: id)] }
            }
            .navigationDestination(for: CounterRoute.self) { route in
                CounterView(dhikrID: route.dhikrID)
            }
        }
    }
}

struct CounterRoute: Hashable {
    let dhikrID: Int64
}
