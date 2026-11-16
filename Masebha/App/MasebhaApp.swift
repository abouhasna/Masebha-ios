import SwiftUI

/// App entry point (≈ the launcher Activity on Android).
@main
struct MasebhaApp: App {
    @State private var startup = AppStartup.makeEnvironment()

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .success(let environment):
                RootView()
                    .environment(environment)
            case .failure(let error):
                StartupErrorView(error: error)
            }
        }
    }
}
