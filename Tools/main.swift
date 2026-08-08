// Pure-logic checks for the Dit & Dah model layer.
//
// Alphabet.swift and MorseCode.swift import nothing but Foundation, so they
// compile and run straight on macOS — no simulator boot, no test target, well
// under a second:
//
//   swiftc -O "DitDah Watch App/Model/Alphabet.swift" \
//             "DitDah Watch App/Model/MorseCode.swift" \
//             Tools/verify.swift -o /tmp/verify && /tmp/verify

import Foundation

var failures: [String] = []
var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
    checks += 1
    if !condition() { failures.append(message()) }
}

func section(_ name: String) { print("\u{001B}[2m—— \(name)\u{001B}[0m") }

// MARK: - Table integrity

section("table integrity")

expect(Alphabet.symbols.count == 42, "expected 42 symbols, got \(Alphabet.symbols.count)")
expect(Alphabet.symbols(in: .letter).count == 26, "expected 26 letters")
expect(Alphabet.symbols(in: .digit).count == 10, "expected 10 digits")
expect(Alphabet.symbols(in: .punctuation).count == 6, "expected 6 punctuation marks")
expect(Alphabet.drillPool.count == 36, "drill pool should be the 36 letters+digits")

// Duplicate patterns would make decoding ambiguous and silently break the keyer.
let patterns = Alphabet.symbols.map(\.morse)
expect(Set(patterns).count == patterns.count, "duplicate Morse patterns in table")

let characters = Alphabet.symbols.map(\.character)
expect(Set(characters).count == characters.count, "duplicate characters in table")

for symbol in Alphabet.symbols {
    expect(!symbol.morse.isEmpty, "\(symbol.character) has an empty pattern")
    expect(
        symbol.morse.allSatisfy { $0 == "." || $0 == "-" },
        "\(symbol.character) pattern has characters other than . and -: \(symbol.morse)"
    )
    expect(
        symbol.morse.count <= 6,
        "\(symbol.character) pattern is \(symbol.morse.count) elements; nothing standard exceeds 6"
    )
    expect(
        String(symbol.character) == symbol.character.uppercased(),
        "\(symbol.character) is not uppercase"
    )
}

// MARK: - Known patterns

section("known patterns")

// Spot-check against the ITU table, including the ones that are easy to
// transpose: B/V/D, F/L, Q/Y, and the digit ramp.
let expectedPatterns: [Character: String] = [
    "E": ".", "T": "-", "A": ".-", "N": "-.",
    "S": "...", "O": "---", "H": "....", "B": "-...", "V": "...-", "D": "-..",
    "F": "..-.", "L": ".-..", "Q": "--.-", "Y": "-.--", "X": "-..-",
    "0": "-----", "1": ".----", "5": ".....", "9": "----.",
    "?": "..--..", "/": "-..-.",
]
for (character, pattern) in expectedPatterns {
    expect(
        MorseCode.pattern(for: character) == pattern,
        "\(character) should be \(pattern), got \(MorseCode.pattern(for: character) ?? "nil")"
    )
}

// SOS is the canonical smoke test.
expect(MorseCode.pattern(for: "S") == "...", "S")
expect(MorseCode.pattern(for: "O") == "---", "O")

// MARK: - Round trips

section("round trips")

for symbol in Alphabet.symbols {
    let elements = symbol.elements
    expect(
        elements.count == symbol.morse.count,
        "\(symbol.character) parsed to \(elements.count) elements from \(symbol.morse.count) chars"
    )
    expect(
        MorseElement.pattern(from: elements) == symbol.morse,
        "\(symbol.character) failed pattern -> elements -> pattern"
    )
    expect(
        MorseCode.character(for: elements) == symbol.character,
        "\(symbol.character) failed encode -> decode"
    )
}

// Lowercase input must encode the same as uppercase.
expect(MorseCode.pattern(for: "a") == MorseCode.pattern(for: "A"), "lowercase 'a' should encode like 'A'")
expect(MorseCode.pattern(for: "z") == "--..", "lowercase 'z' should encode like 'Z'")

// Unknown input decodes to nothing rather than crashing or guessing.
expect(MorseCode.pattern(for: "\u{00E9}") == nil, "unmapped character should return nil")
expect(MorseCode.character(for: "........") == nil, "unmapped pattern should return nil")
expect(MorseCode.character(for: "") == nil, "empty pattern should return nil")

// MARK: - NATO coverage

section("NATO coverage")

for symbol in Alphabet.drillPool {
    expect(symbol.nato?.isEmpty == false, "\(symbol.character) is missing a NATO word")
    expect(symbol.pronunciation?.isEmpty == false, "\(symbol.character) is missing a pronunciation")
}
for symbol in Alphabet.symbols(in: .punctuation) {
    expect(symbol.nato == nil, "\(symbol.character) should not have a NATO word")
}

// The four spellings people most often get wrong, plus the aviation digits.
let expectedWords: [Character: String] = [
    "A": "Alfa", "J": "Juliett", "X": "Xray", "W": "Whiskey", "Q": "Quebec",
]
for (character, word) in expectedWords {
    expect(
        Alphabet.byCharacter[character]?.nato == word,
        "\(character) should be \(word), got \(Alphabet.byCharacter[character]?.nato ?? "nil")"
    )
}
let expectedPronunciations: [Character: String] = [
    "3": "TREE", "4": "FOW-ER", "5": "FIFE", "9": "NIN-ER",
]
for (character, pronunciation) in expectedPronunciations {
    expect(
        Alphabet.byCharacter[character]?.pronunciation == pronunciation,
        "\(character) should be pronounced \(pronunciation)"
    )
}

// Speech uses the real code word, not the hyphenated stress guide — feeding a
// respelling like "al-fah" to the synthesiser makes it sound out the fragments.
let expectedSpeech: [Character: String] = [
    "A": "Alfa", "B": "Bravo", "J": "Juliett", "W": "Whiskey", "Z": "Zulu",
    "X": "X-ray",                                  // "Xray" reads as one garbled token
    "0": "Zero", "1": "One", "2": "Two", "6": "Six", "7": "Seven", "8": "Eight",
    "3": "tree", "4": "fower", "5": "fife", "9": "niner",   // ICAO says these differently
]
for (character, speech) in expectedSpeech {
    expect(
        Alphabet.byCharacter[character]?.spokenPronunciation == speech,
        "\(character) should be spoken as \(speech), got \(Alphabet.byCharacter[character]?.spokenPronunciation ?? "nil")"
    )
}

// Nothing spoken may contain the stress guide's hyphen-separated caps, which is
// what caused the fragments to be read out one at a time.
for symbol in Alphabet.drillPool {
    guard let speech = symbol.spokenPronunciation else { continue }
    expect(!speech.isEmpty, "\(symbol.character) has empty speech text")
    expect(
        speech != symbol.pronunciation,
        "\(symbol.character) is speaking its stress guide (\(speech)) instead of a word"
    )
    expect(
        speech.uppercased() != speech || speech.count <= 3,
        "\(symbol.character) speech \"\(speech)\" is all caps, which reads as an initialism"
    )
}

// Punctuation stays silent — it has no code word to say.
for symbol in Alphabet.symbols(in: .punctuation) {
    expect(symbol.spokenPronunciation == nil, "\(symbol.character) should have no speech text")
}

// MARK: - Timing

section("timing")

// PARIS is 50 units long, so a unit is 1200/wpm ms.
expect(MorseTiming(wpm: 20).unit == 60, "20 wpm -> 60 ms unit, got \(MorseTiming(wpm: 20).unit)")
expect(MorseTiming(wpm: 10).unit == 120, "10 wpm -> 120 ms unit, got \(MorseTiming(wpm: 10).unit)")
expect(MorseTiming(wpm: 5).unit == 240, "5 wpm -> 240 ms unit, got \(MorseTiming(wpm: 5).unit)")

// Sending PARIS once must take exactly one minute's worth of units.
let paris = MorseTiming(wpm: 10)
expect(paris.unit * 50 * 10 == 60_000, "10 wpm should send PARIS 10 times in 60 s")

// WPM is clamped, so a stale stored value can never produce nonsense timing.
expect(MorseTiming(wpm: 0).wpm == 5, "wpm 0 should clamp to 5")
expect(MorseTiming(wpm: 999).wpm == 20, "wpm 999 should clamp to 20")
expect(MorseTiming(wpm: -5).wpm == 5, "negative wpm should clamp to 5")

let t = MorseTiming(wpm: 10)
expect(t.ditDahThreshold == 240, "dit/dah threshold at 10 wpm")
expect(t.characterGap == 360, "character gap is 3 units")
expect(t.wordGap == 840, "word gap is 7 units")
expect(t.duration(of: .dit) == 120, "dit is 1 unit")
expect(t.duration(of: .dah) == 360, "dah is 3 units")

// Boundary behaviour: exactly at the threshold counts as a dah.
expect(t.classify(pressDuration: 0) == .dit, "0 ms is a dit")
expect(t.classify(pressDuration: 119) == .dit, "just under a nominal dit")
expect(t.classify(pressDuration: 239.9) == .dit, "just under threshold is a dit")
expect(t.classify(pressDuration: 240) == .dah, "exactly at threshold is a dah")
expect(t.classify(pressDuration: 360) == .dah, "a nominal dah")
expect(t.classify(pressDuration: 5000) == .dah, "a very long press is still a dah")

// The gap ladder must stay strictly ordered at every speed, or character and
// word boundaries would collapse into each other.
for wpm in MorseTiming.wpmRange {
    let timing = MorseTiming(wpm: wpm)
    expect(
        timing.duration(of: .dit) < timing.ditDahThreshold,
        "\(wpm) wpm: a nominal dit must classify as a dit"
    )
    expect(
        timing.duration(of: .dah) >= timing.ditDahThreshold,
        "\(wpm) wpm: a nominal dah must classify as a dah"
    )
    expect(
        timing.ditDahThreshold < timing.characterGap,
        "\(wpm) wpm: threshold must sit below the character gap"
    )
    expect(
        timing.characterGap < timing.wordGap,
        "\(wpm) wpm: character gap must be shorter than the word gap"
    )
}

// MARK: - Send timeline

section("send timeline")

let cTimeline = t.timeline(for: MorseElement.parse("-.-."))
expect(cTimeline.count == 4, "C has 4 elements")
expect(cTimeline[0].on == 360 && cTimeline[0].off == 120, "C dah then a 1-unit gap")
expect(cTimeline[1].on == 120 && cTimeline[1].off == 120, "C dit then a 1-unit gap")
expect(cTimeline.last?.off == 0, "no trailing gap after the final element")

// Total on+off for a character must match the textbook length: sum of element
// units plus one unit between each pair.
for symbol in Alphabet.symbols {
    let elements = symbol.elements
    let expectedUnits = elements.reduce(0) { $0 + $1.units } + Double(elements.count - 1)
    let actual = t.timeline(for: elements).reduce(0.0) { $0 + $1.on + $1.off }
    expect(
        abs(actual - expectedUnits * t.unit) < 0.001,
        "\(symbol.character) timeline is \(actual) ms, expected \(expectedUnits * t.unit) ms"
    )
}

// MARK: - Report

print("")
if failures.isEmpty {
    print("\u{001B}[32m✓ all \(checks) checks passed\u{001B}[0m")
} else {
    print("\u{001B}[31m✗ \(failures.count) of \(checks) checks failed\u{001B}[0m")
    for failure in failures { print("  • \(failure)") }
    exit(1)
}
