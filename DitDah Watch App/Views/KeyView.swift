import SwiftUI
import WatchKit

/// Screen 1 — tap the key to send Morse.
struct KeyView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(FeedbackEngine.self) private var feedback
    @Environment(KeySession.self) private var session

    @State private var showingSettings = false
    @State private var crownWPM = Double(MorseTiming.defaultWPM)
    @State private var wpmBadgeShown = false
    @State private var badgeTask: Task<Void, Never>?

    private var keyer: Keyer { session.keyer }

    /// The 40 mm SE has about 50 fewer points of usable height than a 46 mm, and
    /// that has to come from somewhere. The readout box and the type inside it
    /// scale together — a `frame(height:)` only constrains layout, so type too
    /// big for its box silently draws over the key below it.
    private static let isCompact = WKInterfaceDevice.current().screenBounds.width < 180
    private static let readoutHeight: CGFloat = isCompact ? 54 : 62
    private static let targetFontSize: CGFloat = isCompact ? 26 : 32
    private static let decodedFontSize: CGFloat = isCompact ? 21 : 26

    var body: some View {
        // No NavigationStack here on purpose. A watchOS nav bar with a title and
        // a toolbar button costs roughly 100 pt of a 250 pt screen — most of the
        // room the key itself needs. The reference screens keep theirs; this one
        // trades it for a bigger target.
        VStack(spacing: 2) {
            readout
            livePattern
            // The key claims whatever is left rather than a computed diameter.
            // Estimating the leftover height meant guessing at safe-area insets
            // and clipping the footer off the bottom of a 40 mm.
            keySlot
            footer
        }
        // Horizontal inset only. watchOS already insets the page for the status
        // clock and the tab dots; adding vertical padding on top of that stacks
        // with the safe area and squeezes the stack until the rows overlap.
        .padding(.horizontal, 8)
        .overlay(alignment: .top) { wpmBadge }
        .pageBackground(Theme.key)
        .sheet(isPresented: $showingSettings) { SettingsSheet() }
        .focusable()
        .digitalCrownRotation(
            $crownWPM,
            from: Double(MorseTiming.wpmRange.lowerBound),
            through: Double(MorseTiming.wpmRange.upperBound),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownWPM) { _, newValue in
            let wpm = Int(newValue.rounded())
            guard wpm != preferences.wpm else { return }
            preferences.wpm = wpm
            flashWPMBadge()
        }
        .onAppear {
            crownWPM = Double(preferences.wpm)
            feedback.activate()
        }
        .onDisappear {
            session.stop()
            badgeTask?.cancel()
        }
    }

    // MARK: - Readout

    @ViewBuilder
    private var readout: some View {
        switch session.mode {
        case .drill: drillReadout
        case .free: freeReadout
        }
    }

    private var drillReadout: some View {
        VStack(spacing: 1) {
            Text("SEND")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text(String(session.target.character))
                .font(.system(size: Self.targetFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(targetColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.snappy, value: session.target.character)

            // After a miss, the answer appears under the letter so the retry is
            // a corrected repetition rather than another guess.
            if case .wrong(let sent) = session.outcome {
                HStack(spacing: 6) {
                    MorsePatternView(elements: MorseElement.parse(sent), unit: 3.5, tint: .red.opacity(0.8))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                    MorsePatternView(elements: session.target.elements, unit: 3.5, tint: Theme.key)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: session.outcome)
        .frame(height: Self.readoutHeight)
    }

    private var freeReadout: some View {
        VStack(spacing: 1) {
            Text("DECODED")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text(session.decoded.isEmpty ? "—" : String(session.decoded.suffix(12)))
                .font(.system(size: Self.decodedFontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(session.decoded.isEmpty ? Color.secondary : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(height: Self.readoutHeight)
    }

    private var targetColor: Color {
        switch session.outcome {
        case .correct: return .green
        case .wrong: return .red
        case nil: return .white
        }
    }

    // MARK: - Live pattern

    /// What you've keyed so far in the current character. Fixed height so the
    /// key button never shifts under your finger mid-press.
    private var livePattern: some View {
        ZStack {
            if keyer.elements.isEmpty {
                Text(session.mode == .drill ? "hold for a dah" : " ")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else {
                MorsePatternView(elements: keyer.elements, unit: 5, tint: .white)
            }
        }
        .frame(height: 13)
        .animation(.easeOut(duration: 0.1), value: keyer.elements)
    }

    // MARK: - The key

    /// Greedy container that hands the key the exact space left over, with the
    /// circle inscribed in it. Capped so it doesn't become a dinner plate on an
    /// Ultra, floored so it stays thumb-sized on the smallest watch.
    private var keySlot: some View {
        GeometryReader { proxy in
            let diameter = max(min(proxy.size.width, proxy.size.height, 112), 54)
            key(diameter: diameter)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func key(diameter: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.key.opacity(keyer.isKeyDown ? 0.95 : 0.32),
                        Theme.key.opacity(keyer.isKeyDown ? 0.45 : 0.05),
                    ],
                    center: .center,
                    startRadius: 1,
                    endRadius: 58
                )
            )
            .overlay(
                Circle().strokeBorder(
                    Theme.key.opacity(keyer.isKeyDown ? 1 : 0.45),
                    lineWidth: keyer.isKeyDown ? 3 : 1.5
                )
            )
            .overlay(
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(keyer.isKeyDown ? .black : Theme.key.opacity(0.85))
            )
            .scaleEffect(keyer.isKeyDown ? 0.93 : 1)
            .shadow(color: Theme.key.opacity(keyer.isKeyDown ? 0.65 : 0), radius: 14)
            .animation(.spring(response: 0.17, dampingFraction: 0.62), value: keyer.isKeyDown)
            // An explicit diameter, because a bare Circle has no intrinsic size:
            // inside a VStack it collapses to a 10 pt ideal rather than filling
            // what's left over.
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            // A Button only reports a completed tap. Morse needs the press and
            // the release as separate, timed events, and a zero-distance drag is
            // the only gesture that gives both.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        // onChanged fires repeatedly while a finger moves, so the
                        // guard keeps one press from restarting the timer.
                        if !keyer.isKeyDown { keyer.keyDown() }
                    }
                    .onEnded { _ in
                        if keyer.isKeyDown { keyer.keyUp() }
                    }
            )
            .accessibilityLabel("Morse key")
            .accessibilityHint("Touch and hold to send. Short is a dit, long is a dah.")
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                session.toggleMode()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: session.mode.symbolName)
                    Text(session.mode.title)
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.key)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mode: \(session.mode.title). Tap to switch.")

            Spacer(minLength: 0)

            switch session.mode {
            case .drill:
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(session.streak > 0 ? Theme.key : .secondary)
                    Text("\(session.streak)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                }
                .animation(.snappy, value: session.streak)
                .accessibilityLabel("Streak \(session.streak)")

            case .free:
                if !session.decoded.isEmpty {
                    Button {
                        session.clearDecoded()
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear decoded text")
                }
            }

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(height: 18)
    }

    // MARK: - WPM badge

    /// Transient speed readout while the crown turns — otherwise the crown
    /// silently changes timing and it feels like the app got worse.
    @ViewBuilder
    private var wpmBadge: some View {
        if wpmBadgeShown {
            Text("\(preferences.wpm) WPM")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.black.opacity(0.75), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.key.opacity(0.6), lineWidth: 1))
                .foregroundStyle(Theme.key)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    private func flashWPMBadge() {
        badgeTask?.cancel()
        withAnimation(.easeOut(duration: 0.12)) { wpmBadgeShown = true }
        badgeTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { wpmBadgeShown = false }
        }
    }
}
