import SwiftUI

/// Owns the objects that must outlive any single view: settings, the audio and
/// haptic engines, and the practice session.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let feedback: FeedbackEngine
    let session: KeySession

    init() {
        let preferences = Preferences()
        let feedback = FeedbackEngine(preferences: preferences)
        self.preferences = preferences
        self.feedback = feedback
        self.session = KeySession(preferences: preferences, feedback: feedback)
    }
}

@main
struct DitDahApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model.preferences)
                .environment(model.feedback)
                .environment(model.session)
                .tint(Theme.key)
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app with a key held would otherwise strand the audio
            // session active and the oscillator sounding.
            if phase != .active {
                model.session.stop()
                model.feedback.deactivate()
            }
        }
    }
}
