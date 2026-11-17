import SwiftUI

/// The Wird tab: the supporter's wirds, or a page that explains the feature to everyone else.
/// The data is never touched when support ends; it is shown again when the user supports.
struct WirdTab: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var path: [WirdRoute] = []

    var body: some View {
        let isSupporter = environment.entitlements.isSupporter
        NavigationStack(path: $path) {
            Group {
                if isSupporter {
                    WirdListView { id in
                        // Replace instead of append: a fast double tap never opens two sessions.
                        if path.isEmpty { path = [WirdRoute(wirdID: id)] }
                    }
                } else {
                    WirdLockedView()
                }
            }
            .navigationDestination(for: WirdRoute.self) { route in
                WirdSessionView(wirdID: route.wirdID)
            }
        }
        .modifier(TabContentTint())
        .onChange(of: isSupporter) { _, supporter in
            if !supporter { path = [] }   // support ended while a wird was open: back to the locked page
        }
    }
}

struct WirdRoute: Hashable {
    let wirdID: Int64
}

/// Shown in the Wird tab to non-supporters (≈ Android's premium popup).
struct WirdLockedView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color(argb: SupportStyle.gold))
                    .padding(.top, 12)
                Text(tr("wird.locked.title"))
                    .appFont(24, .bold)
                    .multilineTextAlignment(.center)
                Text(tr("wird.locked.message"))
                    .appFont(16, .regular)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                SupporterPerks()
                NavigationLink {
                    SupportView()
                } label: {
                    Text(tr("support.title"))
                        .appFont(17, .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Color(argb: SettingsStyle.accent)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wird.becomeSupporter")
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .background(Color(argb: SettingsStyle.background).ignoresSafeArea())
        .navigationTitle(tr("tab.wird"))
        .navigationBarTitleDisplayMode(.inline)
        .themedNavigationBar(environment.palette.tools)
    }
}
