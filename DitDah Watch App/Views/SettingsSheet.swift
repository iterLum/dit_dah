import SwiftUI

struct SettingsSheet: View {
    @Environment(Preferences.self) private var preferences
    @Environment(KeySession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var preferences = preferences

        NavigationStack {
            List {
                Section {
                    Stepper(value: $preferences.wpm, in: MorseTiming.wpmRange) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(preferences.wpm) WPM")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("\(Int(preferences.timing.unit)) ms per dit")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Speed")
                } footer: {
                    Text("Sets how long a press has to be to count as a dah, and how much silence ends a character.")
                        .font(.system(size: 10))
                }

                Section("Feedback") {
                    Toggle(isOn: $preferences.soundEnabled) {
                        Label("Sidetone", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $preferences.hapticsEnabled) {
                        Label("Haptics", systemImage: "hand.tap.fill")
                    }
                }

                Section("Drill") {
                    LabeledContent {
                        Text("\(preferences.bestStreak)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.key)
                    } label: {
                        Label("Best streak", systemImage: "flame.fill")
                    }

                    Button {
                        session.skip()
                        dismiss()
                    } label: {
                        Label("Skip this letter", systemImage: "forward.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
