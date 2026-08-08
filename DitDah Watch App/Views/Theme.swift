import SwiftUI

/// Colours and shared type styles.
///
/// Each page owns a hue so you can tell where you are peripherally, without
/// reading the title — useful on a screen you glance at for half a second.
enum Theme {
    /// Radio-dial amber. Also the app's accent colour.
    static let key = Color(red: 1.00, green: 0.70, blue: 0.25)
    static let morse = Color(red: 0.20, green: 0.78, blue: 0.76)
    static let phonetic = Color(red: 0.56, green: 0.51, blue: 1.00)

    /// Full-bleed page background. Fades to true black at the bottom because on
    /// an OLED watch black is genuinely off — it saves power and makes the
    /// bezel disappear.
    static func background(_ tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.30), tint.opacity(0.06), .black],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Row metrics for the two reference lists.
///
/// watchOS's default rows are chunky enough that only two and a half fit, which
/// is useless for something you look things up in. But the first pass at fixing
/// that overshot: 34 pt is below the ~44 pt minimum that makes a row reliably
/// hittable with a fingertip. 44 is the floor, and roughly four rows still fit.
enum ReferenceRow {
    static let minHeight: CGFloat = 44
    static let insets = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
}

extension View {
    /// Tinted gradient behind a tab page that has no navigation chrome.
    func pageBackground(_ tint: Color) -> some View {
        containerBackground(Theme.background(tint), for: .tabView)
    }

    /// Tinted gradient behind a navigation screen. Applied inside the
    /// `NavigationStack`, since the stack draws its own opaque background over
    /// anything set at the tab-view level.
    func navigationBackground(_ tint: Color) -> some View {
        containerBackground(Theme.background(tint), for: .navigation)
    }
}
