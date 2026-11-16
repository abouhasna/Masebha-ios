import SwiftUI

/// Wird (daily routines) is a supporter feature built in Leap 2. Until then this tab explains it.
struct WirdPlaceholderView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let palette = environment.palette
        let textColor = Color(argb: ColorMath.isLight(palette.background) ? 0xFF1E_1E1E : 0xFFFF_FFFF)
        NavigationStack {
            ZStack {
                ThemedBackground(color: palette.background, pattern: environment.showsPattern)
                VStack(spacing: 16) {
                    Image("TabWird")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    Text(tr("wird.placeholder.title"))
                        .appFont(24, .bold)
                    Text(tr("wird.placeholder.message"))
                        .appFont(17, .regular)
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                }
                .foregroundStyle(textColor)
                .padding(32)
            }
            .navigationTitle(tr("tab.wird"))
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar(palette.tools)
        }
    }
}
