import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var state
    @State private var scrollMetrics = ScrollMetrics(offset: 0, contentHeight: 0, viewportHeight: 0)
    @State private var isActivityCollapsed = false

    /// Scroll past this to auto-collapse. Hysteresis below prevents jitter
    /// near the threshold.
    private let collapseThreshold: CGFloat = 30
    private let expandThreshold: CGFloat = 4
    /// Rubber-band overscroll past this magnitude re-expands the chart.
    /// Lets the user summon the chart back even when the list is too
    /// short to scroll (no offset > 0 to come back from).
    private let overscrollExpandThreshold: CGFloat = 15

    var body: some View {
        @Bindable var state = state

        VStack(spacing: 0) {
            HeaderView()

            ActivityCalendar(
                dailyTotals: state.combinedDailyTotals(),
                selectedDate: $state.selectedDate,
                title: "ACTIVITY"
            )
            .padding(.horizontal, 14)
            .padding(.bottom, isActivityCollapsed ? 0 : 10)
            .frame(height: isActivityCollapsed ? 0 : nil, alignment: .top)
            .opacity(isActivityCollapsed ? 0 : 1)
            .clipped()
            .allowsHitTesting(!isActivityCollapsed)

            Divider().opacity(0.5)

            SearchBar(text: $state.searchQuery)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ProjectListView { metrics in
                scrollMetrics = metrics
            }

            Divider().opacity(0.5)

            FooterView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: isActivityCollapsed)
        .onChange(of: scrollMetrics) { _, m in
            if !isActivityCollapsed {
                if m.offset > collapseThreshold {
                    isActivityCollapsed = true
                }
            } else {
                // Two ways out of collapsed state:
                //   • Pulled up past the top (rubber-band overscroll). This
                //     is the only escape on a short list, since there's no
                //     positive offset to come back from.
                //   • Scrolled back near the top of an actually-scrollable
                //     list. Gated on `hasOverflow` so the post-collapse
                //     clamp-to-0 on a short list doesn't immediately
                //     re-expand and start an oscillation.
                let pulledUp = m.offset < -overscrollExpandThreshold
                let hasOverflow = m.contentHeight > m.viewportHeight + 1
                let scrolledBackToTop = m.offset < expandThreshold && hasOverflow
                if pulledUp || scrolledBackToTop {
                    isActivityCollapsed = false
                }
            }
        }
        // Reset collapsed state when the filter changes — the new project list
        // may be short enough that it can't be scrolled, leaving the user with
        // no way to expand the chart back.
        .onChange(of: state.selectedRange) { _, _ in isActivityCollapsed = false }
        .onChange(of: state.searchQuery) { _, _ in isActivityCollapsed = false }
        .onChange(of: state.selectedDate) { _, _ in isActivityCollapsed = false }
        .onChange(of: state.trackingSource) { _, _ in isActivityCollapsed = false }
        .onChange(of: state.mergeOverlaps) { _, _ in isActivityCollapsed = false }
    }
}
