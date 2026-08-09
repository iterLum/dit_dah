import AVFoundation

/// A continuous 600 Hz sine that gets gated on and off — the same way a real CW
/// sidetone works.
///
/// Playing a pre-rendered beep per element would drift, because each element has
/// a different length and `AVAudioPlayer` start latency is not free. Keeping one
/// oscillator running and only moving its amplitude means key-down to sound is a
/// single sample-accurate ramp.
final class Sidetone {
    /// Mutable state shared with the audio render thread.
    ///
    /// The render block runs on a real-time thread and must not allocate, lock,
    /// or call into Swift runtime machinery. It only ever reads `target` and
    /// mutates its own `phase`/`amplitude`; the main thread only ever writes
    /// `target`. Single-word aligned stores make that safe in practice, and it
    /// is the pattern Apple's own oscillator samples use.
    private final class State {
        var phase: Double = 0
        var phaseIncrement: Double = 0
        var amplitude: Double = 0
        var target: Double = 0
        var rampPerSample: Double = 0
    }

    /// Comfortable listening level. Full scale would clip against the watch
    /// speaker's limiter and sound harsh.
    private static let peakAmplitude = 0.22
    /// Attack/decay length. Gating a sine instantly produces a broadband click at
    /// every edge; a few milliseconds of ramp removes it without smearing a dit.
    private static let rampSeconds = 0.005

    private let engine = AVAudioEngine()
    private let state = State()
    private let frequency: Double
    private var sourceNode: AVAudioSourceNode?
    private var isConfigured = false

    init(frequency: Double = 600) {
        self.frequency = frequency
    }

    /// Spin up the audio graph. Safe to call repeatedly.
    ///
    /// Any failure here is non-fatal by design: the watch may have no route
    /// available, or the session may be claimed by another app. Sound simply
    /// stays silent and haptics carry the feedback.
    /// Build the graph if needed and start rendering.
    ///
    /// The caller must have activated the audio session already. Session
    /// ownership lives in `FeedbackEngine` because speech shares the same
    /// session, and having two owners activate it independently was what made
    /// the first tap on the phonetic screen hang.
    ///
    /// Order still matters inside here: the graph is built only once the
    /// session is live, because until then the output node reports a
    /// placeholder format — often 0 Hz and the wrong channel count — and a node
    /// connected at a format the hardware doesn't use makes the engine hand the
    /// render block zero-length buffers.
    @discardableResult
    func start() -> Bool {
        if !isConfigured { configure() }
        guard isConfigured else { return false }

        do {
            if !engine.isRunning { try engine.start() }
            return true
        } catch {
            return false
        }
    }

    /// Release the output entirely, leaving the session alone so speech can use
    /// it without the oscillator competing for the same hardware.
    ///
    /// `stop()` rather than `pause()` on purpose: pausing halts rendering but
    /// keeps the engine's audio units allocated and holding the output, which
    /// leaves the speech synthesiser contending with a graph that is still
    /// nominally attached to the hardware.
    func suspend() {
        state.target = 0
        state.amplitude = 0
        if engine.isRunning { engine.stop() }
    }

    func keyDown() {
        state.target = Self.peakAmplitude
    }

    func keyUp() {
        state.target = 0
    }

    private func configure() {
        let hardwareFormat = engine.outputNode.inputFormat(forBus: 0)
        // Belt and braces: the session is active by now, but never divide by zero.
        let sampleRate = hardwareFormat.sampleRate > 0 ? hardwareFormat.sampleRate : 44_100

        state.phaseIncrement = 2 * .pi * frequency / sampleRate
        state.rampPerSample = Self.peakAmplitude / (Self.rampSeconds * sampleRate)

        // Mono. A sine has no stereo content, and hard-coding two channels was
        // the other half of the zero-length-buffer bug — the watch speaker isn't
        // necessarily stereo. Let the main mixer handle any up-mix.
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }

        let state = self.state
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // Move one ramp step toward the target before emitting the sample.
                if state.amplitude < state.target {
                    state.amplitude = min(state.target, state.amplitude + state.rampPerSample)
                } else if state.amplitude > state.target {
                    state.amplitude = max(state.target, state.amplitude - state.rampPerSample)
                }

                let sample = Float(sin(state.phase) * state.amplitude)

                state.phase += state.phaseIncrement
                if state.phase > 2 * .pi { state.phase -= 2 * .pi }

                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    // Respect the buffer's real capacity rather than trusting
                    // frameCount. Writing past it would corrupt memory on the
                    // audio thread, which is not a crash anyone wants to debug.
                    let capacity = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    guard frame < capacity else { continue }
                    data.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        // Pin the mixer's output to the hardware format too, so the engine never
        // has to guess at a conversion between the mixer and the speaker.
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)
        sourceNode = node
        isConfigured = true
    }
}
