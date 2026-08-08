import SwiftUI

/// Screen 2 — every character and its Morse pattern. Tap a row to hear and feel it.
struct MorseReferenceView: View {
    @Environment(FeedbackEngine.self) private var feedback

    var body: some View {
        NavigationStack {
            List {
                ForEach(Symbol.Category.allCases, id: \.self) { category in
                    Section {
                        ForEach(Alphabet.symbols(in: category)) { symbol in
                            row(for: symbol)
                        }
                    } header: {
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.morse)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(4)
            .environment(\.defaultMinListRowHeight, 34)
            .scrollContentBackground(.hidden)
            .navigationTitle("Morse")
            .navigationBackground(Theme.morse)
            .tint(Theme.morse)
        }
        .onDisappear { feedback.cancelPlayback() }
    }

    private func row(for symbol: Symbol) -> some View {
        let isPlaying = feedback.playingCharacter == symbol.character

        return Button {
            feedback.play(symbol)
        } label: {
            HStack(spacing: 10) {
                Text(String(symbol.character))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPlaying ? Theme.morse : .white)
                    .frame(width: 22, alignment: .leading)

                MorsePatternView(
                    elements: symbol.elements,
                    unit: 5,
                    tint: isPlaying ? Theme.morse : .white.opacity(0.75)
                )

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(.referenceRow)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.morse.opacity(isPlaying ? 0.30 : 0.11))
                .padding(.vertical, 1)
        )
        .animation(.easeOut(duration: 0.15), value: isPlaying)
        .accessibilityLabel("\(String(symbol.character)), \(spokenPattern(symbol))")
        .accessibilityHint("Plays the pattern")
    }

    /// VoiceOver reads "dot dot dash" rather than the punctuation of the pattern.
    private func spokenPattern(_ symbol: Symbol) -> String {
        symbol.elements
            .map { $0 == .dit ? "dot" : "dash" }
            .joined(separator: " ")
    }
}
