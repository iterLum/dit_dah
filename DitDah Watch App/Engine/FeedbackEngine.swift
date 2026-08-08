import AVFoundation
import Observation
import WatchKit

/// Everything the app does to your ears and wrist, in one place.
///
/// The keyer, the drill grader, and both reference screens all route feedback
/// through here so that the sound/haptics preferences are honoured in exactly
/// one spot instead of being re-checked at every call site.
@MainActor
@Observable
final class FeedbackEngine {
    private let preferences: Preferences
    private let sidetone = Sidetone()
    private let synthesizer = AVSpeechSynthesizer()

    /// The character currently being played back, so a reference row can
    /// highlight itself while it sounds.
    private(set) var playingCharacter: Character?

    private var playbackTask: Task<Void, Never>?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Session

    func activate() {
        guard preferences.soundEnabled else { return }
        sidetone.activate()
    }

    func deactivate() {
        cancelPlayback()
        sidetone.deactivate()
    }

    // MARK: - Live keying

    func keyDown() {
        guard preferences.soundEnabled else { return }
        sidetone.activate()
        sidetone.keyDown()
    }

    func keyUp() {
        sidetone.keyUp()
    }

    /// Fired when a press has been classified, so you feel what you just sent.
    ///
    /// `.click` is a single crisp tap and `.start` is a longer buzz, which maps
    /// about as closely onto dit and dah as the fixed haptic vocabulary allows —
    /// watchOS gives no way to vary tap duration directly.
    func tap(for element: MorseElement) {
        guard preferences.hapticsEnabled else { return }
        WKInterfaceDevice.current().play(element == .dit ? .click : .start)
    }

    func success() {
        guard preferences.hapticsEnabled else { return }
        WKInterfaceDevice.current().play(.success)
    }

    func failure() {
        guard preferences.hapticsEnabled else { return }
        WKInterfaceDevice.current().play(.failure)
    }

    // MARK: - Playback

    /// Send a character as sound and haptics at the current speed.
    ///
    /// Starting a new playback cancels the one in flight, so hammering rows in
    /// the reference list never overlaps two characters.
    func play(_ symbol: Symbol) {
        let timing = preferences.timing
        cancelPlayback()
        playingCharacter = symbol.character

        playbackTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.sidetone.keyUp()
                if self.playingCharacter == symbol.character { self.playingCharacter = nil }
            }

            self.activate()
            for step in timing.timeline(for: symbol.elements) {
                if Task.isCancelled { return }
                self.keyDown()
                self.tap(for: step.element)
                try? await Task.sleep(for: .milliseconds(Int(step.on)))
                self.keyUp()
                if step.off > 0 {
                    try? await Task.sleep(for: .milliseconds(Int(step.off)))
                }
            }
        }
    }

    func cancelPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        sidetone.keyUp()
        playingCharacter = nil
    }

    // MARK: - Speech

    /// Speak an ICAO code word.
    ///
    /// The text passed in is the code word itself — "Alfa", "Niner" — not the
    /// hyphenated stress guide shown on screen. The synthesiser knows these
    /// words; handing it a respelling makes it sound out the fragments.
    func speak(_ text: String) {
        guard preferences.soundEnabled else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Default rate. Slowing a single short word down just makes it drawl.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
