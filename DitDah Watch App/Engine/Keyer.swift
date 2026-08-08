import Foundation
import Observation

/// Turns press-and-release events into Morse characters.
///
/// The state machine is small: a press is timed and classified as a dit or dah,
/// and it is *silence* that ends things — 3 units of it closes the character,
/// 7 units closes the word. That means the user never taps a "done" button; the
/// rhythm itself is the input, which is the whole point of learning Morse.
@MainActor
@Observable
final class Keyer {
    /// Elements keyed so far in the character being built.
    private(set) var elements: [MorseElement] = []
    private(set) var isKeyDown = false

    /// Fired at a character boundary with the decoded character (nil when the
    /// pattern isn't in the table) and the raw pattern that was sent, so a drill
    /// can show what you actually keyed rather than just "wrong".
    var onCharacter: ((Character?, String) -> Void)?
    /// Fired one word gap after the last character, if nothing else was keyed.
    var onWordGap: (() -> Void)?

    /// Read live from preferences rather than copied at init, so turning the
    /// Digital Crown changes classification and gap length on the very next
    /// press with no state to keep in sync.
    var timing: MorseTiming { preferences.timing }

    private let feedback: FeedbackEngine
    private let preferences: Preferences
    private var pressStart: Date?
    private var gapTask: Task<Void, Never>?

    init(feedback: FeedbackEngine, preferences: Preferences) {
        self.feedback = feedback
        self.preferences = preferences
    }

    /// The in-progress character as `.`/`-` text.
    var currentPattern: String { MorseElement.pattern(from: elements) }

    func keyDown() {
        // Any pending character/word boundary is void the moment the key goes
        // back down — this press belongs to the character still being built.
        gapTask?.cancel()
        gapTask = nil

        pressStart = Date()
        isKeyDown = true
        feedback.keyDown()
    }

    func keyUp() {
        // Defends against a release with no matching press, which SwiftUI can
        // deliver if a gesture is interrupted.
        guard let pressStart else { return }

        let milliseconds = Date().timeIntervalSince(pressStart) * 1000
        let element = timing.classify(pressDuration: milliseconds)

        self.pressStart = nil
        isKeyDown = false
        elements.append(element)

        feedback.keyUp()
        feedback.tap(for: element)

        scheduleBoundaries()
    }

    /// Drop everything, including a key that is still held. Called when the view
    /// goes away so a backgrounded app can't leave the sidetone running.
    func reset() {
        gapTask?.cancel()
        gapTask = nil
        pressStart = nil
        isKeyDown = false
        elements = []
        feedback.keyUp()
    }

    /// Discard the in-progress character without emitting it.
    func clearCurrent() {
        gapTask?.cancel()
        gapTask = nil
        elements = []
    }

    private func scheduleBoundaries() {
        let characterGap = Int(timing.characterGap.rounded())
        let remainderToWordGap = Int((timing.wordGap - timing.characterGap).rounded())

        gapTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(characterGap))
            guard !Task.isCancelled, let self else { return }
            self.commitCharacter()

            try? await Task.sleep(for: .milliseconds(remainderToWordGap))
            guard !Task.isCancelled else { return }
            self.onWordGap?()
        }
    }

    private func commitCharacter() {
        guard !elements.isEmpty else { return }
        let pattern = currentPattern
        elements = []
        onCharacter?(MorseCode.character(for: pattern), pattern)
    }
}
