import Foundation

/// One row of the alphabet: a character, its Morse pattern, and — for letters and
/// digits — its ICAO/NATO code word.
///
/// This is the single source of truth for the whole app. The Morse encoder, the
/// decoder, and both reference screens all read from `Alphabet.symbols`; nothing
/// keeps a second copy of the alphabet.
struct Symbol: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case letter = "Letters"
        case digit = "Numbers"
        case punctuation = "Punctuation"
    }

    /// The character this row represents, always uppercase.
    let character: Character
    /// Morse pattern written with `.` for a dit and `-` for a dah.
    let morse: String
    /// ICAO code word, e.g. `Alfa`. Nil for punctuation, which has no code word.
    let nato: String?
    /// ICAO stress guide, e.g. `AL-FAH`. Shown on screen as a reading aid — it is
    /// *not* what gets spoken. Feeding a hyphenated respelling to the speech
    /// synthesiser makes it read the fragments as a nonsense word.
    let pronunciation: String?
    let category: Category

    var id: Character { character }

    /// The Morse pattern as drawable elements.
    var elements: [MorseElement] { MorseElement.parse(morse) }

    /// Text handed to `AVSpeechSynthesizer` — the real code word, which the
    /// synthesiser already knows how to say.
    ///
    /// Only the handful in `speechOverrides` differ, and they matter: ICAO
    /// *writes* "Three" and "Nine" but *says* "tree" and "niner", which is the
    /// entire reason the digits have their own code words.
    var spokenPronunciation: String? {
        Self.speechOverrides[character] ?? nato
    }

    private static let speechOverrides: [Character: String] = [
        "X": "X-ray",   // "Xray" gets read as a single garbled token
        "3": "tree",
        "4": "fower",
        "5": "fife",
        "9": "niner",
    ]
}

enum Alphabet {
    /// 26 letters, 10 digits, 6 punctuation marks.
    ///
    /// NATO spellings follow ICAO Annex 10 exactly: `Alfa` (not Alpha),
    /// `Juliett` (two t's), `Xray` (no hyphen). Digit code words carry the
    /// aviation pronunciations — `tree`, `fow-er`, `fife`, `niner` — which exist
    /// so digits stay distinguishable over a noisy radio link.
    static let symbols: [Symbol] = [
        Symbol(character: "A", morse: ".-",     nato: "Alfa",     pronunciation: "AL-FAH",       category: .letter),
        Symbol(character: "B", morse: "-...",   nato: "Bravo",    pronunciation: "BRAH-VOH",     category: .letter),
        Symbol(character: "C", morse: "-.-.",   nato: "Charlie",  pronunciation: "CHAR-LEE",     category: .letter),
        Symbol(character: "D", morse: "-..",    nato: "Delta",    pronunciation: "DELL-TAH",     category: .letter),
        Symbol(character: "E", morse: ".",      nato: "Echo",     pronunciation: "ECK-OH",       category: .letter),
        Symbol(character: "F", morse: "..-.",   nato: "Foxtrot",  pronunciation: "FOKS-TROT",    category: .letter),
        Symbol(character: "G", morse: "--.",    nato: "Golf",     pronunciation: "GOLF",         category: .letter),
        Symbol(character: "H", morse: "....",   nato: "Hotel",    pronunciation: "HOH-TELL",     category: .letter),
        Symbol(character: "I", morse: "..",     nato: "India",    pronunciation: "IN-DEE-AH",    category: .letter),
        Symbol(character: "J", morse: ".---",   nato: "Juliett",  pronunciation: "JEW-LEE-ETT",  category: .letter),
        Symbol(character: "K", morse: "-.-",    nato: "Kilo",     pronunciation: "KEY-LOH",      category: .letter),
        Symbol(character: "L", morse: ".-..",   nato: "Lima",     pronunciation: "LEE-MAH",      category: .letter),
        Symbol(character: "M", morse: "--",     nato: "Mike",     pronunciation: "MIKE",         category: .letter),
        Symbol(character: "N", morse: "-.",     nato: "November", pronunciation: "NO-VEM-BER",   category: .letter),
        Symbol(character: "O", morse: "---",    nato: "Oscar",    pronunciation: "OSS-CAH",      category: .letter),
        Symbol(character: "P", morse: ".--.",   nato: "Papa",     pronunciation: "PAH-PAH",      category: .letter),
        Symbol(character: "Q", morse: "--.-",   nato: "Quebec",   pronunciation: "KEH-BECK",     category: .letter),
        Symbol(character: "R", morse: ".-.",    nato: "Romeo",    pronunciation: "ROW-ME-OH",    category: .letter),
        Symbol(character: "S", morse: "...",    nato: "Sierra",   pronunciation: "SEE-AIR-RAH",  category: .letter),
        Symbol(character: "T", morse: "-",      nato: "Tango",    pronunciation: "TANG-GO",      category: .letter),
        Symbol(character: "U", morse: "..-",    nato: "Uniform",  pronunciation: "YOU-NEE-FORM", category: .letter),
        Symbol(character: "V", morse: "...-",   nato: "Victor",   pronunciation: "VIK-TAH",      category: .letter),
        Symbol(character: "W", morse: ".--",    nato: "Whiskey",  pronunciation: "WISS-KEY",     category: .letter),
        Symbol(character: "X", morse: "-..-",   nato: "Xray",     pronunciation: "ECKS-RAY",     category: .letter),
        Symbol(character: "Y", morse: "-.--",   nato: "Yankee",   pronunciation: "YANG-KEY",     category: .letter),
        Symbol(character: "Z", morse: "--..",   nato: "Zulu",     pronunciation: "ZOO-LOO",      category: .letter),

        Symbol(character: "0", morse: "-----",  nato: "Zero",     pronunciation: "ZE-RO",        category: .digit),
        Symbol(character: "1", morse: ".----",  nato: "One",      pronunciation: "WUN",          category: .digit),
        Symbol(character: "2", morse: "..---",  nato: "Two",      pronunciation: "TOO",          category: .digit),
        Symbol(character: "3", morse: "...--",  nato: "Three",    pronunciation: "TREE",         category: .digit),
        Symbol(character: "4", morse: "....-",  nato: "Four",     pronunciation: "FOW-ER",       category: .digit),
        Symbol(character: "5", morse: ".....",  nato: "Five",     pronunciation: "FIFE",         category: .digit),
        Symbol(character: "6", morse: "-....",  nato: "Six",      pronunciation: "SIX",          category: .digit),
        Symbol(character: "7", morse: "--...",  nato: "Seven",    pronunciation: "SEV-EN",       category: .digit),
        Symbol(character: "8", morse: "---..",  nato: "Eight",    pronunciation: "AIT",          category: .digit),
        Symbol(character: "9", morse: "----.",  nato: "Nine",     pronunciation: "NIN-ER",       category: .digit),

        Symbol(character: ".", morse: ".-.-.-", nato: nil, pronunciation: nil, category: .punctuation),
        Symbol(character: ",", morse: "--..--", nato: nil, pronunciation: nil, category: .punctuation),
        Symbol(character: "?", morse: "..--..", nato: nil, pronunciation: nil, category: .punctuation),
        Symbol(character: "/", morse: "-..-.",  nato: nil, pronunciation: nil, category: .punctuation),
        Symbol(character: "=", morse: "-...-",  nato: nil, pronunciation: nil, category: .punctuation),
        Symbol(character: "+", morse: ".-.-.",  nato: nil, pronunciation: nil, category: .punctuation),
    ]

    static func symbols(in category: Symbol.Category) -> [Symbol] {
        symbols.filter { $0.category == category }
    }

    /// Letters and digits only — the pool the drill picks targets from.
    /// Punctuation is reference material, not something worth drilling.
    static let drillPool: [Symbol] = symbols.filter { $0.category != .punctuation }

    static let byCharacter: [Character: Symbol] = Dictionary(
        uniqueKeysWithValues: symbols.map { ($0.character, $0) }
    )

    /// Reverse map for decoding. Built once; every pattern in the table is unique,
    /// which `Tools/verify.swift` asserts.
    static let byPattern: [String: Symbol] = Dictionary(
        uniqueKeysWithValues: symbols.map { ($0.morse, $0) }
    )
}
