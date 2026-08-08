# Dit & Dah

A watch-only Morse code and NATO phonetic trainer for Apple Watch. Three screens,
no account, no network, no ads.

| Screen | What it does |
| --- | --- |
| **Key** | Tap and hold the button to send Morse. Drill mode grades you against a target letter; Free mode decodes whatever you tap into text. |
| **Morse** | Every letter, digit, and common punctuation mark with its pattern. Tap a row to hear and feel it. |
| **Phonetic** | Every letter and digit with its ICAO/NATO code word and pronunciation. Tap a row to hear it. |

Swipe left and right between the three. The Digital Crown scrolls the reference
lists, and on the Key screen it sets your speed.

## How the keying works

Timing follows the standard PARIS reference word, so what you learn here
transfers to real CW. One Morse time unit is `1200 / WPM` milliseconds — 120 ms
at the default 10 WPM.

| Event | Rule |
| --- | --- |
| Dit | Press shorter than 2 units |
| Dah | Press of 2 units or longer |
| End of character | 3 units of silence |
| End of word | 7 units of silence |

You never tap a "done" button — silence is what ends a character, the same way it
does on a real key.

The dit/dah threshold is fixed to the current WPM rather than adapting to your
recent presses. An adaptive keyer re-tunes as you drift, so an identical press
can be graded differently on two attempts; that is fine for an expert and
confusing while learning. Turn the crown on the Key screen to change speed
(5–20 WPM).

In Drill mode a miss keeps the same target letter and reveals what you sent next
to what you should have sent, so your next attempt is a corrected repetition
rather than a fresh guess.

## Feedback

- **Sidetone** — a real 600 Hz oscillator gated on and off, with a 5 ms ramp at
  each edge so keying doesn't click. Off by preference, and it degrades silently
  to haptics if the audio session is unavailable.
- **Haptics** — a short tap for a dit, a longer buzz for a dah. The simulator has
  no Taptic Engine, so this only means anything on a real watch.
- **Speech** — the phonetic screen speaks the code word itself ("Alfa",
  "Bravo"). The `AL-FAH` line under it is a reading aid for your eyes only;
  handing that respelling to the speech synthesiser makes it read the fragments
  as a nonsense word. Digits are the exception, because ICAO *writes* "Three"
  and "Nine" but *says* "tree" and "niner" — those speak the aviation form.

## Building

Everything is driven off one table in `DitDah Watch App/Model/Alphabet.swift` —
the encoder, the decoder, and both reference screens. There is no second copy of
the alphabet anywhere.

Run the model checks (about a second, no simulator needed):

```bash
./Tools/verify.sh
```

Build and run in the simulator:

```bash
xcodebuild -project DitDah.xcodeproj -scheme DitDah -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' CODE_SIGNING_ALLOWED=NO build
```

Regenerate the app icon after editing `Tools/make-icon.swift`:

```bash
swift Tools/make-icon.swift
```

## Putting it on your watch

The project ships unsigned, so this part is a one-time setup in Xcode:

1. Open `DitDah.xcodeproj`.
2. Xcode → Settings → Accounts, add your Apple ID. A free account is enough.
3. Select the **DitDah** target → Signing & Capabilities → tick *Automatically
   manage signing* and pick your **Personal Team**.
4. Choose your watch as the run destination and press Run.

Builds signed with a free account stop working after 7 days and need a re-run
from Xcode. A paid Apple Developer account removes that limit.

## Layout

```
DitDah Watch App/
├── DitDahApp.swift       App entry, owns the long-lived objects
├── Model/
│   ├── Alphabet.swift    The table — single source of truth
│   ├── MorseCode.swift   Encode, decode, PARIS timing
│   └── Preferences.swift Settings, persisted to UserDefaults
├── Engine/
│   ├── Keyer.swift       Press/release → characters
│   ├── KeySession.swift  Drill and free-mode state
│   ├── FeedbackEngine.swift  Sound, haptics, speech in one place
│   └── Sidetone.swift    The oscillator
└── Views/                One file per screen, plus Theme and the pattern glyphs
```
