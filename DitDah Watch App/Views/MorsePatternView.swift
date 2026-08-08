import SwiftUI

/// Draws a Morse pattern as shapes rather than text.
///
/// `·−·` set in a font is nearly unreadable at watch size — the glyphs are tiny,
/// baseline-aligned, and vary between fonts. Drawing them means a dit is a dot
/// and a dah is three times as wide, so the 1:3 timing ratio you are trying to
/// learn is visible in the shape itself.
struct MorsePatternView: View {
    let elements: [MorseElement]
    /// Height of a mark, and the width of a dit. A dah is three of these.
    var unit: CGFloat = 5
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: unit * 0.8) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                // A capsule as wide as it is tall is a circle, so one shape
                // renders both marks and the 1:3 ratio falls out of the width.
                Capsule(style: .continuous)
                    .frame(width: unit * element.units, height: unit)
            }
        }
        .foregroundStyle(tint)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        MorsePatternView(elements: MorseElement.parse("...."), tint: Theme.morse)
        MorsePatternView(elements: MorseElement.parse("-.-."), tint: Theme.morse)
        MorsePatternView(elements: MorseElement.parse("-----"), unit: 7, tint: Theme.key)
    }
}
