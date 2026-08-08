import Foundation

/// A single Morse element: one short mark or one long mark.
enum MorseElement: Hashable {
    case dit
    case dah

    /// Length in Morse time units. A dit is 1 unit, a dah is 3 — this ratio is
    /// what the whole timing system is built on.
    var units: Double {
        switch self {
        case .dit: return 1
        case .dah: return 3
        }
    }

    var symbol: Character {
        switch self {
        case .dit: return "."
        case .dah: return "-"
        }
    }

    static func parse(_ pattern: String) -> [MorseElement] {
        pattern.compactMap {
            switch $0 {
            case ".": return .dit
            case "-": return .dah
            default: return nil
            }
        }
    }

    static func pattern(from elements: [MorseElement]) -> String {
        String(elements.map(\.symbol))
    }
}

enum MorseCode {
    static func pattern(for character: Character) -> String? {
        Alphabet.byCharacter[Character(character.uppercased())]?.morse
    }

    static func elements(for character: Character) -> [MorseElement]? {
        pattern(for: character).map(MorseElement.parse)
    }

    static func character(for pattern: String) -> Character? {
        Alphabet.byPattern[pattern]?.character
    }

    static func character(for elements: [MorseElement]) -> Character? {
        character(for: MorseElement.pattern(from: elements))
    }
}

/// Timing derived from words-per-minute using the standard PARIS reference word.
///
/// Everything the keyer and the playback engine do about time comes from here, so
/// changing WPM changes send speed, dit/dah classification, and gap detection
/// together and stays internally consistent.
struct MorseTiming: Equatable {
    /// Practical range for a finger on a watch face. Below 5 the gaps feel like
    /// the app has hung; above 20 a dit is under 60 ms and taps get misread.
    static let wpmRange: ClosedRange<Int> = 5...20
    static let defaultWPM = 10

    let wpm: Int

    init(wpm: Int = MorseTiming.defaultWPM) {
        self.wpm = min(max(wpm, Self.wpmRange.lowerBound), Self.wpmRange.upperBound)
    }

    /// Duration of one Morse time unit in milliseconds. PARIS is 50 units long,
    /// so at W words per minute a unit is 1200/W ms.
    var unit: Double { 1200.0 / Double(wpm) }

    /// A press shorter than this is a dit, anything longer is a dah. Two units is
    /// the midpoint between a 1-unit dit and a 3-unit dah.
    var ditDahThreshold: Double { unit * 2 }

    /// Silence this long ends the current character (standard: 3 units).
    var characterGap: Double { unit * 3 }

    /// Silence this long also ends the current word (standard: 7 units).
    var wordGap: Double { unit * 7 }

    func duration(of element: MorseElement) -> Double { unit * element.units }

    /// Classify a key press by how long it was held.
    ///
    /// The threshold is fixed to the current WPM rather than adapting to the
    /// user's recent presses. An adaptive keyer re-tunes as you drift, which
    /// means an identical press can be graded differently on two attempts —
    /// fine for an expert, confusing for someone learning. Fixed is predictable,
    /// and WPM is one turn of the Digital Crown away.
    func classify(pressDuration: Double) -> MorseElement {
        pressDuration < ditDahThreshold ? .dit : .dah
    }

    /// The on/off timeline for sending a character: each mark paired with the
    /// silence that follows it inside the character.
    func timeline(for elements: [MorseElement]) -> [(element: MorseElement, on: Double, off: Double)] {
        elements.enumerated().map { index, element in
            (element, duration(of: element), index == elements.count - 1 ? 0 : unit)
        }
    }
}
