import SwiftUI
import StoreKit

/// The bottom tabs: Azkar | Wird | More (replaces the Android bottom navigation and side drawer).
///
/// Apple's standard tab bar: iOS colors the bar and its icons itself (on iOS 26 the glass picks
/// dark or light icons from what is behind it), so it stays readable on every theme. Only the
/// selected tab is green: a darker green on light glass, a brighter one on dark glass (the
/// "TabSelected" color has both, and iOS picks).
struct MainTabView: View {
    @State private var selection: Tab = .azkar

    enum Tab: Hashable {
        case azkar, wird, more
    }

    var body: some View {
        TabView(selection: $selection) {
            AzkarTab()
                .tabItem { Label { Text(tr("tab.azkar")) } icon: { Image("TabAzkar") } }
                .tag(Tab.azkar)
                .accessibilityIdentifier("tab.azkar")
            WirdTab()
                .tabItem { Label { Text(tr("tab.wird")) } icon: { Image("TabWird") } }
                .tag(Tab.wird)
            MoreTab()
                .tabItem { Label(tr("tab.more"), systemImage: "ellipsis.circle.fill") }
                .tag(Tab.more)
        }
        .tint(Color("TabSelected"))
        .modifier(LaunchPopupsPresenter())
    }
}

/// Navigation of the Azkar tab: the list, and the counter screen pushed on top of it.
struct AzkarTab: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.requestReview) private var requestReview
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
        .modifier(TabContentTint())
        .onChange(of: path) { old, new in
            // Back from counting, once, from the 7th launch: Apple's own rating prompt (Apple
            // decides whether it really shows; it never shows more than 3 times a year).
            if !old.isEmpty && new.isEmpty && environment.takeReviewTurn() {
                requestReview()
            }
        }
    }
}

struct CounterRoute: Hashable {
    let dhikrID: Int64
}

/// Buttons inside a tab ("Done", back arrows) use the theme's toolbar accent, made readable on
/// the toolbar color. Applied inside each tab, never on the TabView, so the tab bar keeps iOS's colors.
struct TabContentTint: ViewModifier {
    @Environment(AppEnvironment.self) private var environment

    func body(content: Content) -> some View {
        let palette = environment.palette
        content.tint(Color(argb: ColorMath.readableIcon(accent: palette.toolsAccent, on: palette.tools)))
    }
}
