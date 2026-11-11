import SwiftUI

/// App entry point (≈ the Application class + launcher Activity on Android).
@main
struct MasebhaApp: App {
    var body: some Scene {
        WindowGroup {
            PipelineCheckView()
        }
    }
}
