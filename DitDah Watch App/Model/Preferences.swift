import Foundation
import Observation

/// User settings, persisted to `UserDefaults` on write.
///
/// A single observable object rather than `@AppStorage` scattered through the
/// views, because the engine layer needs to read these too and views are not a
/// good place for the engines to reach into.
@Observable
final class Preferences {
    private enum Key {
        static let wpm = "wpm"
        static let sound = "soundEnabled"
        static let haptics = "hapticsEnabled"
        static let bestStreak = "bestStreak"
    }

    private let defaults: UserDefaults

    /// Send speed. Everything about timing derives from this.
    var wpm: Int {
        didSet { defaults.set(wpm, forKey: Key.wpm) }
    }

    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Key.sound) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.haptics) }
    }

    var bestStreak: Int {
        didSet { defaults.set(bestStreak, forKey: Key.bestStreak) }
    }

    /// Derived timing. `MorseTiming` clamps, so a corrupted stored WPM can never
    /// produce a zero-length unit.
    var timing: MorseTiming { MorseTiming(wpm: wpm) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedWPM = defaults.integer(forKey: Key.wpm)
        wpm = storedWPM == 0 ? MorseTiming.defaultWPM : storedWPM
        soundEnabled = defaults.object(forKey: Key.sound) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        bestStreak = defaults.integer(forKey: Key.bestStreak)
    }

    func recordStreak(_ streak: Int) {
        if streak > bestStreak { bestStreak = streak }
    }
}
