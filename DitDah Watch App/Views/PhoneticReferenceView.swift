import SwiftUI

/// Screen 3 — every letter and digit with its ICAO/NATO code word.
/// Tap a row to hear the aviation pronunciation.
struct PhoneticReferenceView: View {
    @Environment(FeedbackEngine.self) private var feedback

    /// Punctuation has no code word, so this list covers letters and digits only.
    private let categories: [Symbol.Category] = [.letter, .digit]

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.self) { category in
                    Section {
                        ForEach(Alphabet.symbols(in: category)) { symbol in
                            row(for: symbol)
                        }
                    } header: {
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.phonetic)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(4)
            .environment(\.defaultMinListRowHeight, 36)
            .scrollContentBackground(.hidden)
            .navigationTitle("Phonetic")
            .navigationBackground(Theme.phonetic)
            .tint(Theme.phonetic)
        }
    }

    private func row(for symbol: Symbol) -> some View {
        Button {
            if let text = symbol.spokenPronunciation { feedback.speak(text) }
        } label: {
            HStack(spacing: 10) {
                Text(String(symbol.character))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.phonetic)
                    .frame(width: 22, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    Text(symbol.nato ?? "")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    // The stress guide is the point for digits: the code word is
                    // "Nine" but you say "NIN-er".
                    if let pronunciation = symbol.pronunciation {
                        Text(pronunciation)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(.referenceRow)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.phonetic.opacity(0.11))
                .padding(.vertical, 1)
        )
        .accessibilityLabel("\(String(symbol.character)), \(symbol.nato ?? "")")
        .accessibilityHint("Speaks the pronunciation")
    }
}
