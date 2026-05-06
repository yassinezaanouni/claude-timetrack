import SwiftUI

/// Shown in place of the flat project list when "Merge overlaps" is on.
///
/// Concurrent multi-project windows are grouped into cards (each lists its
/// contributors and how much each contributed). Non-overlapping time appears
/// under "Solo". A single project can show up in multiple windows AND under
/// Solo if it has both kinds of work in scope.
struct OverlapBreakdownView: View {
    @Environment(AppState.self) private var state
    let breakdown: AppState.OverlapBreakdown

    var body: some View {
        if breakdown.windows.isEmpty && breakdown.solo.isEmpty {
            EmptyOverlapState()
        } else {
            // Lazy: cards/rows below the fold are only realized as the user
            // scrolls past them.
            LazyVStack(spacing: 10) {
                if !breakdown.windows.isEmpty {
                    sectionLabel("OVERLAPS", count: breakdown.windows.count)
                    ForEach(Array(breakdown.windows.enumerated()), id: \.1.id) { idx, window in
                        OverlapWindowCard(index: idx + 1, window: window)
                    }
                }

                if !breakdown.solo.isEmpty {
                    sectionLabel("SOLO", count: breakdown.solo.count)
                        .padding(.top, breakdown.windows.isEmpty ? 0 : 4)
                    let peak = breakdown.solo.first?.activeSeconds ?? 1
                    ForEach(breakdown.solo) { entry in
                        SoloProjectRow(entry: entry, peak: peak)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
    }

    private func sectionLabel(_ text: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.mutedForeground)
                .tracking(0.7)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.muted)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Overlap window card

private struct OverlapWindowCard: View {
    let index: Int
    let window: AppState.OverlapWindow

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Text("\(index)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primary)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Overlap")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .tracking(0.6)
                    Text(timeRangeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.foreground)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(TimeFormat.short(window.duration))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.foreground)
                        .monospacedDigit()
                    Text("\(window.entries.count) projects")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Project contributors
            VStack(spacing: 2) {
                ForEach(window.entries) { entry in
                    OverlapEntryRow(entry: entry, windowDuration: window.duration)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.primary.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var timeRangeLabel: String {
        let cal = Calendar.current
        let sameDay = cal.isDate(window.start, inSameDayAs: window.end)
        let timeFmt = Self.timeFormatter
        let dayFmt  = Self.dayFormatter

        if sameDay {
            // If the window is from today we drop the date entirely.
            let today = cal.startOfDay(for: Date())
            let windowDay = cal.startOfDay(for: window.start)
            let prefix = cal.isDate(today, inSameDayAs: windowDay)
                ? ""
                : "\(dayFmt.string(from: window.start)) · "
            return "\(prefix)\(timeFmt.string(from: window.start))–\(timeFmt.string(from: window.end))"
        } else {
            return "\(dayFmt.string(from: window.start)) \(timeFmt.string(from: window.start))–\(dayFmt.string(from: window.end)) \(timeFmt.string(from: window.end))"
        }
    }
}

// MARK: - Per-project rows inside an overlap card

private struct OverlapEntryRow: View {
    @Environment(AppState.self) private var state
    let entry: AppState.OverlapWindow.Entry
    let windowDuration: TimeInterval
    @State private var hovering = false

    var body: some View {
        let proportion = windowDuration > 0
            ? min(1, entry.activeSeconds / windowDuration)
            : 0
        let accent = Color.paletteColor(for: entry.projectName)

        Button {
            state.selectedProjectRoot = entry.projectRoot
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)

                Text(entry.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                // Compact share bar — meters how much of the window this
                // project contributed to.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accent.opacity(0.18))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accent)
                            .frame(width: max(2, geo.size.width * CGFloat(proportion)))
                    }
                }
                .frame(width: 44, height: 3)

                Text(TimeFormat.short(entry.activeSeconds))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.foreground)
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(hovering ? Theme.card : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help("Open \(entry.projectName)")
    }
}

// MARK: - Solo row

private struct SoloProjectRow: View {
    @Environment(AppState.self) private var state
    let entry: AppState.SoloEntry
    /// Largest solo activeSeconds in the visible set — used as the
    /// proportional bar's denominator so the longest entry fills the row.
    let peak: TimeInterval
    @State private var hovering = false

    var body: some View {
        let accent = Color.paletteColor(for: entry.projectName)
        let proportion = peak > 0 ? entry.activeSeconds / peak : 0

        Button {
            state.selectedProjectRoot = entry.projectRoot
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)

                    Text(entry.projectName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    Text(TimeFormat.short(entry.activeSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.foreground)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.muted)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: max(2, geo.size.width * CGFloat(proportion)))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(hovering ? Theme.accent : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        }
        .buttonStyle(.plain)
        .onHover { h in
            hovering = h
            if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .help("Open \(entry.projectName)")
    }
}

// MARK: - Empty state

private struct EmptyOverlapState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.mutedForeground.opacity(0.5))
            Text("No activity in this range.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}
