import SwiftUI

/// First launch: the user picks Arabic or English before anything else
/// (≈ LanguageSelectionActivity). The text is bilingual because no language is chosen yet.
struct LanguagePickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(argb: 0xFF20_2020).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "globe")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Color(argb: 0xFF00_9736))
                VStack(spacing: 8) {
                    Text(verbatim: "اختر لغة التطبيق")
                        .font(.custom("IBMPlexSansArabic-Bold", size: 26))
                    Text(verbatim: "Choose the app language")
                        .font(.custom("IBMPlexSansArabic-Medium", size: 20))
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                VStack(spacing: 14) {
                    choice("العربية", language: .arabic, identifier: "language.arabic")
                    choice("English", language: .english, identifier: "language.english")
                }
                .padding(.horizontal, 32)
                Spacer()
                Spacer()
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .alert(Text(verbatim: "تعذّر الحفظ / Couldn't save"), isPresented: $failed) {
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: {
            Text(verbatim: "حاول مرة أخرى.\nPlease try again.")
        }
    }

    private func choice(_ title: String, language: AppLanguage, identifier: String) -> some View {
        Button {
            do {
                try environment.completeOnboarding(with: language)
            } catch {
                failed = true
            }
        } label: {
            Text(verbatim: title)
                .font(.custom("IBMPlexSansArabic-Medium", size: 20))
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(argb: 0xFF00_9736)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
