import SwiftUI

/// The three screens, side by side.
///
/// Horizontal paging rather than watchOS's vertical paging on purpose: vertical
/// paging binds the Digital Crown to page navigation, and the crown is needed
/// here to scroll the reference lists and to set speed on the key screen.
struct RootView: View {
    private enum Page: Hashable {
        case key, morse, phonetic
    }

    @State private var page: Page = .key

    var body: some View {
        TabView(selection: $page) {
            // A paging TabView keeps adjacent pages alive, so KeyView can't rely
            // on onDisappear to know it's off screen. Without this it holds
            // Digital Crown focus while you're reading the reference lists,
            // which spams "overrelease of detent assertion detected".
            KeyView(isActive: page == .key).tag(Page.key)
            MorseReferenceView().tag(Page.morse)
            PhoneticReferenceView().tag(Page.phonetic)
        }
        .tabViewStyle(.page)
    }
}
