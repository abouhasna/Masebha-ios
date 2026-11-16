import SwiftUI

/// Shows the language choice on the very first launch, then the main tabs.
/// Applies the language direction (right-to-left in Arabic) and the font to every screen.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let settings = environment.settings
        Group {
            if settings.languageChosen {
                MainTabView()
            } else {
                LanguagePickerView()
            }
        }
        .appLanguageAndFont(environment)
        .task {
            await environment.refreshReminder()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await environment.refreshReminder() }
            }
        }
    }
}

extension View {
    /// Language direction (right-to-left in Arabic), locale and font of the app. Applied at the
    /// root and again on every sheet, because sheets do not always inherit them.
    func appLanguageAndFont(_ environment: AppEnvironment) -> some View {
        let language = environment.settings.language
        return self
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, language.locale)
            .environment(\.appFontFamily, environment.fontFamily)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Shown only if the database could not be opened. The app never starts with empty data instead.
struct StartupErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("تعذّر فتح بيانات التطبيق\nCouldn't open the app data")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("أعد تشغيل الهاتف ثم افتح التطبيق مرة أخرى. إذا استمرت المشكلة راسلنا على masebha0@gmail.com\n\nRestart your phone and open the app again. If it keeps happening, write to masebha0@gmail.com")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(String(describing: error))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
