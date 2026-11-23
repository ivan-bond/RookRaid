import SwiftUI

/// Pages of the main tabs, side by side, with a horizontal swipe between neighbours.
///
/// Replaces `TabView(.page)`: its UIKit page controller sometimes showed a blank page (after jumping over several
/// tabs or after a full-screen game closed), and pages it considered off screen could not present sheets – so
/// buttons like the flame or trophy pill did nothing. Here every page is a plain SwiftUI view in the window.
/// Only the current page and its neighbours are built; the others are empty until you get close.
struct TabPager<Page: View>: View {
    @Binding var tab: RootTab
    let pages: [RootTab]
    @ViewBuilder let page: (RootTab) -> Page

    @StateObject private var lock = PagerLock()
    @State private var offset: CGFloat = 0
    /// nil = not decided yet, true = horizontal swipe (pages move), false = vertical (the page scrolls).
    @State private var horizontal: Bool?

    private var index: Int { pages.firstIndex(of: tab) ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            HStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.element) { i, t in
                    Group {
                        if abs(i - index) <= 1 { page(t) } else { Color.clear }
                    }
                    .frame(width: w, height: geo.size.height)
                    .clipped()
                    // Pages beside the visible one take no taps (they would sit under the finger while swiping).
                    .allowsHitTesting(i == index)
                    .accessibilityHidden(i != index)
                }
            }
            .frame(width: w, height: geo.size.height, alignment: .leading)
            .offset(x: -CGFloat(index) * w + offset)
            .environment(\.pagerLock, lock)
            .simultaneousGesture(swipe(width: w))
        }
        .clipped()
    }

    private func swipe(width w: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { v in
                guard !lock.blocked else { return }
                if horizontal == nil {
                    horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.4
                }
                guard horizontal == true else { return }
                var dx = v.translation.width
                // Rubber band at the first and last page
                if (index == 0 && dx > 0) || (index == pages.count - 1 && dx < 0) { dx /= 3 }
                offset = dx
            }
            .onEnded { v in
                defer { horizontal = nil }
                guard horizontal == true, !lock.blocked else {
                    if offset != 0 { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { offset = 0 } }
                    return
                }
                let predicted = v.predictedEndTranslation.width
                var next = index
                if predicted < -w * 0.35 || v.translation.width < -w * 0.5 { next = min(pages.count - 1, index + 1) }
                if predicted > w * 0.35 || v.translation.width > w * 0.5 { next = max(0, index - 1) }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    tab = pages[next]
                    offset = 0
                }
            }
    }
}

/// Set while a finger is on a horizontal scroller inside a page (e.g. the card filter), so that the pager
/// does not swipe at the same time.
final class PagerLock: ObservableObject {
    var blocked = false
}

private struct PagerLockKey: EnvironmentKey {
    static let defaultValue: PagerLock? = nil
}

extension EnvironmentValues {
    /// The lock of the surrounding tab pager (nil outside the pager, e.g. in previews and sheets).
    var pagerLock: PagerLock? {
        get { self[PagerLockKey.self] }
        set { self[PagerLockKey.self] = newValue }
    }
}

extension View {
    /// For horizontal scrollers inside a tab page: while touched, the pages do not swipe.
    func blocksPagerSwipe() -> some View { modifier(BlocksPagerSwipe()) }
}

private struct BlocksPagerSwipe: ViewModifier {
    @Environment(\.pagerLock) private var lock

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in lock?.blocked = true }
                .onEnded { _ in lock?.blocked = false }
        )
    }
}
