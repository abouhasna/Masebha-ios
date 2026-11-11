import SwiftUI

/// Temporary Leap 0 screen. It only proves that the cloud build, the tests,
/// and the install on a real iPhone all work. Leap 1 replaces it with the Azkar list.
struct PipelineCheckView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("pipeline.title")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("pipeline.title")

            Text("pipeline.subtitle")
                .font(.body)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("pipeline.subtitle")

            Text(verbatim: "\(AppInfo.version) (\(AppInfo.build))")
                .font(.footnote.monospacedDigit())
                .opacity(0.6)
                .accessibilityIdentifier("pipeline.version")
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground"))
    }
}

#Preview {
    PipelineCheckView()
}
