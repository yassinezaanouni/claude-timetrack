import SwiftUI

struct HeaderView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 28, height: 28)
                    .background(Theme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Claude Time Track")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                    Text(lastRefreshedSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mutedForeground)
                        .monospacedDigit()
                }

                Spacer()
            }

            HStack(spacing: 8) {
                SourcePicker()
                Spacer()
                TimeRangePicker()
            }

            TotalBar()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var lastRefreshedSubtitle: String {
        let prefix = state.trackingSource.label
        if state.isRefreshing { return "\(prefix) · updating…" }
        guard let d = state.lastRefreshedAt else { return "\(prefix) · not yet refreshed" }
        return "\(prefix) · updated \(TimeFormat.relative(from: d))"
    }
}

// MARK: - Total bar

private struct TotalBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let projects = state.visibleProjects()
        let total = state.displayTotal()

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(TimeFormat.short(total))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.foreground)
                    .monospacedDigit()
                if let dayHint = TimeFormat.daysHint(total) {
                    Text(dayHint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.mutedForeground)
                        .monospacedDigit()
                }
                rangeOrDateLabel
                Spacer()
                if !projects.isEmpty {
                    Text("\(projects.count) project\(projects.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.mutedForeground)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.muted)
                        .clipShape(Capsule())
                }
            }

            StackedBar(projects: projects, total: total)
                .frame(height: 8)
        }
    }

    /// Switches between "today / this week / all time" and the drill-in date
    /// label (with a tap-to-clear affordance) so the user always knows which
    /// scope the big number reflects.
    @ViewBuilder
    private var rangeOrDateLabel: some View {
        if let date = state.selectedDate {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { state.selectedDate = nil }
            } label: {
                HStack(spacing: 3) {
                    Text(Self.dayFormatter.string(from: date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.foreground)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mutedForeground)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.primary.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .help("Clear date filter")
        } else {
            Text(state.selectedRange.label.lowercased())
                .font(.system(size: 12))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
}

// MARK: - Stacked bar showing project breakdown

private struct StackedBar: View {
    let projects: [ProjectUsage]
    let total: TimeInterval
    @Environment(AppState.self) private var state

    var body: some View {
        GeometryReader { geo in
            if total <= 0 {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.muted)
            } else {
                HStack(spacing: 1.5) {
                    ForEach(projects) { p in
                        let seconds = state.displaySeconds(for: p)
                        if seconds > 0 {
                            Color.paletteColor(for: p.name)
                                .frame(width: max(3, geo.size.width * CGFloat(seconds / total)))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

// MARK: - Range picker

struct TimeRangePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.primary) { range in
                segmentButton(range)
            }
            moreMenu
        }
        .padding(2)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func segmentButton(_ range: TimeRange) -> some View {
        let active = state.selectedRange == range
        return Button {
            select(range)
        } label: {
            Text(range.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? Theme.primaryForeground : Theme.mutedForeground)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(active ? Theme.primary : Color.clear)
                )
        }
        .plainButton()
    }

    /// Holds the secondary ranges (yesterday / last week / this month /
    /// last month). When one is active the chip lights up and shows the
    /// short label so the user can see the scope at a glance; otherwise
    /// it's a tight ellipsis icon to keep the row compact.
    private var moreMenu: some View {
        let active = !state.selectedRange.isPrimary
        return Menu {
            ForEach(TimeRange.secondary) { range in
                Button(range.label) { select(range) }
            }
        } label: {
            Group {
                if active {
                    HStack(spacing: 3) {
                        Text(state.selectedRange.shortLabel)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(active ? Theme.primaryForeground : Theme.mutedForeground)
            .padding(.horizontal, active ? 9 : 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(active ? Theme.primary : Color.clear)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func select(_ range: TimeRange) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            state.selectedRange = range
            state.selectedDate = nil    // picking a range exits day-drill
        }
    }
}

// MARK: - Source picker (Claude vs Git)

struct SourcePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrackingSource.allCases) { source in
                let isActive = state.trackingSource == source
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        state.trackingSource = source
                    }
                } label: {
                    HStack(spacing: 5) {
                        SourceIcon(source: source, size: 10)
                        Text(source.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isActive ? Theme.primaryForeground : Theme.mutedForeground)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isActive ? Theme.primary : Color.clear)
                    )
                }
                .plainButton()
            }
        }
        .padding(2)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Search bar

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.mutedForeground)

            TextField("Search projects", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
                .foregroundStyle(Theme.foreground)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mutedForeground)
                }
                .plainButton()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.muted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(focused ? Theme.primary.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}
