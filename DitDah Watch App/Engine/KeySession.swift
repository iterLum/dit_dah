import Foundation
import Observation

/// State for the practice screen: which mode it's in, what the drill is asking
/// for, and what has been decoded so far.
///
/// This lives outside the view because the keyer's callbacks outlive any single
/// view update — wiring them to `@State` in a `View` struct would mean reasoning
/// about which copy of the struct a closure captured.
@MainActor
@Observable
final class KeySession {
    enum Mode: CaseIterable {
        case drill
        case free

        var title: String { self == .drill ? "Drill" : "Free" }
        var symbolName: String { self == .drill ? "target" : "text.alignleft" }
    }

    enum Outcome: Equatable {
        case correct
        /// Carries the pattern that was actually sent, so the miss can be shown
        /// against the right answer instead of a bare ✗.
        case wrong(String)
    }

    /// Longest run of decoded text kept in free mode. The watch shows a dozen
    /// characters at most; the rest is history nobody scrolls back through.
    private static let decodedLimit = 60

    var mode: Mode = .drill {
        didSet {
            guard mode != oldValue else { return }
            resetRound()
        }
    }

    private(set) var target: Symbol
    private(set) var streak = 0
    private(set) var outcome: Outcome?
    private(set) var decoded = ""

    let keyer: Keyer

    private let preferences: Preferences
    private let feedback: FeedbackEngine
    private var advanceTask: Task<Void, Never>?

    init(preferences: Preferences, feedback: FeedbackEngine) {
        self.preferences = preferences
        self.feedback = feedback
        self.keyer = Keyer(feedback: feedback, preferences: preferences)
        self.target = Alphabet.drillPool.randomElement() ?? Alphabet.symbols[0]

        keyer.onCharacter = { [weak self] character, pattern in
            self?.handle(character: character, pattern: pattern)
        }
        keyer.onWordGap = { [weak self] in
            self?.appendWordSpace()
        }
    }

    var bestStreak: Int { preferences.bestStreak }

    // MARK: - Input

    private func handle(character: Character?, pattern: String) {
        switch mode {
        case .free:
            // "?" rather than dropping the character: a pattern that decodes to
            // nothing is usually a mistimed press, and seeing it is the feedback.
            decoded.append(character ?? "?")
            if decoded.count > Self.decodedLimit {
                decoded.removeFirst(decoded.count - Self.decodedLimit)
            }

        case .drill:
            if pattern == target.morse {
                outcome = .correct
                streak += 1
                preferences.recordStreak(streak)
                feedback.success()
                advance(after: .milliseconds(550))
            } else {
                outcome = .wrong(pattern)
                streak = 0
                feedback.failure()
                // Deliberately keeps the same target and reveals the answer, so
                // the next attempt is a corrected repetition rather than a fresh
                // guess at a different letter.
            }
        }
    }

    private func appendWordSpace() {
        guard mode == .free, !decoded.isEmpty, decoded.last != " " else { return }
        decoded.append(" ")
    }

    // MARK: - Drill control

    private func advance(after delay: Duration) {
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.nextTarget()
        }
    }

    func nextTarget() {
        var candidate = Alphabet.drillPool.randomElement() ?? target
        // Two of the same character in a row reads as a bug, and drilling a
        // letter you just sent teaches nothing.
        var attempts = 0
        while candidate.character == target.character, attempts < 8 {
            candidate = Alphabet.drillPool.randomElement() ?? target
            attempts += 1
        }
        target = candidate
        outcome = nil
        keyer.clearCurrent()
    }

    func skip() {
        advanceTask?.cancel()
        streak = 0
        nextTarget()
    }

    func clearDecoded() {
        decoded = ""
    }

    func toggleMode() {
        mode = mode == .drill ? .free : .drill
    }

    private func resetRound() {
        advanceTask?.cancel()
        outcome = nil
        keyer.clearCurrent()
    }

    /// Called when the screen goes away, so a held key can't leave the sidetone
    /// sounding or a pending advance firing in the background.
    func stop() {
        advanceTask?.cancel()
        advanceTask = nil
        keyer.reset()
    }
}
