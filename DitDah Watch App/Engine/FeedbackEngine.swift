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
    private var tailTapTask: Task<Void, Never>?

    /// Whether the shared audio session has been activated.
    ///
    /// `setActive(true)` is a synchronous call that can block for a noticeable
    /// stretch. Doing it on every utterance is what made the phonetic screen
    /// freeze on the first tap and only speak after several more.
    private var sessionActive = false

    /// Resolving a voice is slow the first time and identical every time after,
    /// so it is resolved once rather than per utterance.
    ///
    /// `@ObservationIgnored` because `@Observable` rewrites stored properties
    /// into computed ones, and `lazy` isn't allowed on those.
    @ObservationIgnored private lazy var voice = AVSpeechSynthesisVoice(language: "en-US")

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Session

    /// Single owner of the audio session. Both the oscillator and the speech
    /// synthesiser go through here.
    @discardableResult
    private func activateSession() -> Bool {
        if sessionActive { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            sessionActive = true
            return true
        } catch {
            return false
        }
    }

    func activate() {
        guard preferences.soundEnabled, activateSession() else { return }
        sidetone.start()
    }

    func deactivate() {
        cancelPlayback()
        sidetone.suspend()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sessionActive = false
    }

    /// Park the oscillator so the speech synthesiser has the output to itself.
    /// Called when the phonetic screen appears, so the first tap doesn't pay for
    /// tearing the engine down.
    func prepareForSpeech() {
        cancelPlayback()
        sidetone.suspend()
    }

    // MARK: - Live keying

    func keyDown() {
        guard preferences.soundEnabled, activateSession() else { return }
        sidetone.start()
        sidetone.keyDown()
    }

    func keyUp() {
        sidetone.keyUp()
    }

    /// Fired when a press has been classified, so you feel what you just sent.
    ///
    /// Both marks use `.click`, which is the one genuinely silent haptic. A dah
    /// gets a second click shortly after so it still feels longer than a dit.
    ///
    /// This used to send `.start` for a dah. That is an *alert* haptic: watchOS
    /// pairs it with an audible chime, so every dah rang a bell over the top of
    /// the sidetone. There is no variable-duration haptic on watchOS — a second
    /// tap is the only way to make a dah feel longer without making noise.
    func tap(for element: MorseElement) {
        guard preferences.hapticsEnabled else { return }
        WKInterfaceDevice.current().play(.click)
        guard element == .dah else { return }

        tailTapTask?.cancel()
        tailTapTask = Task {
            // Comfortably shorter than a dit at the fastest speed, so the pair
            // still reads as one mark rather than two.
            try? await Task.sleep(for: .milliseconds(55))
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.click)
        }
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
        tailTapTask?.cancel()
        tailTapTask = nil
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
        // The oscillator and the synthesiser share one output. Leaving the
        // engine rendering while speech starts is what made the first tap stall.
        sidetone.suspend()
        guard activateSession() else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        // Default rate. Slowing a single short word down just makes it drawl.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }
}
