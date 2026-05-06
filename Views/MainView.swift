import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var state
    @State private var scrollOffset: CGFloat = 0
    @State private var isActivityCollapsed = false

    /// Scroll past this to auto-collapse. Hysteresis below prevents jitter
    /// near the threshold.
    private let collapseThreshold: CGFloat = 30
    private let expandThreshold: CGFloat = 4

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

            ProjectListView { newOffset in
                scrollOffset = newOffset
            }

            Divider().opacity(0.5)

            FooterView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: isActivityCollapsed)
        .onChange(of: scrollOffset) { _, newValue in
            if !isActivityCollapsed, newValue > collapseThreshold {
                isActivityCollapsed = true
            } else if isActivityCollapsed, newValue < expandThreshold {
                isActivityCollapsed = false
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
