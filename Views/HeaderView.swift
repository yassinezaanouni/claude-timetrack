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

                VStack(alignment: .trailing, spacing: 4) {
                    TimeRangePicker()
                    SourcePicker()
                }
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
        let total = state.totalSeconds(for: state.selectedRange)

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
                Text(state.selectedRange.label.lowercased())
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mutedForeground)
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
                        let seconds = p.seconds(for: state.selectedRange, source: state.trackingSource)
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
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        state.selectedRange = range
                    }
                } label: {
                    Text(range.shortLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(state.selectedRange == range
                            ? Theme.primaryForeground
                            : Theme.mutedForeground)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(state.selectedRange == range ? Theme.primary : Color.clear)
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

// MARK: - Source picker (Claude vs Git)

struct SourcePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrackingSource.allCases) { source in
                let isActive = state.trackingSource == source
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        state.trackingSource = source
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(source.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(isActive ? Theme.foreground : Theme.mutedForeground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isActive ? Theme.card : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(isActive ? Theme.border : .clear, lineWidth: 0.5)
                            )
                    )
                }
                .plainButton()
            }
        }
        .padding(2)
        .background(Theme.muted)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
