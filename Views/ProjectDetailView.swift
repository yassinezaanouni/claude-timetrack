import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        SourcePicker()
                        Spacer()
                    }

                    StatsRow(project: project)

                    Sparkline(project: project)

                    if state.trackingSource == .claude {
                        SessionList(project: project)
                    } else {
                        GitInfoCard(project: project)
                    }

                    CalculationNote(
                        source: state.trackingSource,
                        idleGapMinutes: state.idleGapMinutes,
                        gitMaxGapMinutes: state.gitMaxGapMinutes,
                        gitFirstCommitMinutes: state.gitFirstCommitMinutes
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                state.selectedProjectRoot = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.primary)
            }
            .plainButton()

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.paletteColor(for: project.name))
                    .frame(width: 6, height: 6)
                Text(project.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                state.openInFinder(project.root)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
            }
            .plainButton()
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

// MARK: - Stats row

private struct StatsRow: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage

    var body: some View {
        let claudeAvailable = project.sessionCount > 0
        let gitAvailable = project.commitCount > 0
        let last = project.lastActive(source: state.trackingSource)

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                DualTimeBox(
                    label: "Today",
                    project: project,
                    range: .today,
                    activeSource: state.trackingSource,
                    claudeAvailable: claudeAvailable,
                    gitAvailable: gitAvailable
                )
                DualTimeBox(
                    label: "Week",
                    project: project,
                    range: .week,
                    activeSource: state.trackingSource,
                    claudeAvailable: claudeAvailable,
                    gitAvailable: gitAvailable
                )
                DualTimeBox(
                    label: "All time",
                    project: project,
                    range: .all,
                    activeSource: state.trackingSource,
                    claudeAvailable: claudeAvailable,
                    gitAvailable: gitAvailable
                )
            }

            if state.trackingSource == .claude {
                HStack(spacing: 8) {
                    StatBox(label: "Sessions", value: "\(project.sessionCount)")
                    StatBox(label: "Messages", value: "\(project.messageCount)")
                    StatBox(label: "Last",     value: last.map { TimeFormat.relative(from: $0) } ?? "—")
                }
            } else {
                HStack(spacing: 8) {
                    StatBox(label: "Commits", value: "\(project.commitCount)")
                    StatBox(label: "Last",    value: last.map { TimeFormat.relative(from: $0) } ?? "—")
                    Color.clear.frame(maxWidth: .infinity).frame(height: 0)
                }
            }
        }
    }
}

private struct DualTimeBox: View {
    @Environment(AppState.self) private var state
    let label: String
    let project: ProjectUsage
    let range: TimeRange
    let activeSource: TrackingSource
    let claudeAvailable: Bool
    let gitAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
                .tracking(0.4)

            TimeChip(
                source: .claude,
                active: activeSource == .claude,
                available: claudeAvailable,
                seconds: project.seconds(for: range, source: .claude),
                size: .stat,
                onTap: { switchSource(to: .claude) }
            )
            TimeChip(
                source: .git,
                active: activeSource == .git,
                available: gitAvailable,
                seconds: project.seconds(for: range, source: .git),
                size: .stat,
                onTap: { switchSource(to: .git) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: activeSource)
    }

    private func switchSource(to source: TrackingSource) {
        guard state.trackingSource != source else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            state.trackingSource = source
        }
    }
}

private struct StatBox: View {
    let label: String
    let value: String
    var hint: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
                .tracking(0.4)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.foreground)
                    .monospacedDigit()
                if let hint {
                    Text(hint)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.mutedForeground)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Sparkline (last 14 days)

private struct Sparkline: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage

    var body: some View {
        let days = buildDays()
        let maxSeconds = max(days.map(\.seconds).max() ?? 0, 1)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LAST 14 DAYS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
                    .tracking(0.5)
                Spacer()
                Text(TimeFormat.short(days.reduce(0) { $0 + $1.seconds }))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .monospacedDigit()
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(days) { day in
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(day.seconds > 0
                                ? Color.paletteColor(for: project.name)
                                : Theme.muted)
                            .frame(height: barHeight(day.seconds, max: maxSeconds))
                            .help(tooltip(for: day))
                        Text(day.shortLabel)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 60)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    private func barHeight(_ seconds: TimeInterval, max: TimeInterval) -> CGFloat {
        guard max > 0 else { return 2 }
        let ratio = CGFloat(seconds / max)
        return Swift.max(2, ratio * 44)
    }

    private func tooltip(for day: DayBucket) -> String {
        "\(day.fullLabel): \(TimeFormat.short(day.seconds))"
    }

    private func buildDays() -> [DayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var out: [DayBucket] = []
        let fmtShort = DateFormatter()
        fmtShort.dateFormat = "d"
        let fmtWeekday = DateFormatter()
        fmtWeekday.dateFormat = "EEE"
        let fmtFull = DateFormatter()
        fmtFull.dateFormat = "EEE, MMM d"

        let dailies = project.dailyTotals(source: state.trackingSource)

        for i in (0..<14).reversed() {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let seconds = dailies[day] ?? 0
            let weekday = cal.component(.weekday, from: day)
            // 1=Sun
            let weekdayLabel: String
            if i == 0 {
                weekdayLabel = "•"     // today
            } else if weekday == 2 {
                weekdayLabel = "M"
            } else {
                weekdayLabel = fmtShort.string(from: day)
            }
            out.append(DayBucket(id: day, seconds: seconds,
                                 shortLabel: weekdayLabel,
                                 fullLabel: fmtFull.string(from: day)))
        }
        return out
    }

    private struct DayBucket: Identifiable {
        let id: Date
        let seconds: TimeInterval
        let shortLabel: String
        let fullLabel: String
    }
}

// MARK: - Session list

private struct SessionList: View {
    let project: ProjectUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
                    .tracking(0.5)
                Spacer()
                Text("\(project.sessions.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .monospacedDigit()
            }

            VStack(spacing: 4) {
                ForEach(project.sessions.prefix(20)) { session in
                    SessionRow(session: session)
                }
                if project.sessions.count > 20 {
                    Text("+ \(project.sessions.count - 20) older sessions")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
    }
}

private struct SessionRow: View {
    @Environment(AppState.self) private var state
    let session: SessionSummary

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(whenLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.foreground)
                Text("\(session.messageCount) msgs · \(rangeLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mutedForeground)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Text(TimeFormat.short(session.activeSeconds))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.foreground)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(hovering ? Theme.accent : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .onHover { hovering = $0 }
        .onTapGesture {
            state.openInFinder(session.jsonlPath)
        }
        .help("Click to reveal session file in Finder")
    }

    private var whenLabel: String {
        let cal = Calendar.current
        let fmtDateTime = DateFormatter()
        fmtDateTime.dateFormat = "EEE, MMM d"

        if cal.isDateInToday(session.start) { return "Today" }
        if cal.isDateInYesterday(session.start) { return "Yesterday" }
        return fmtDateTime.string(from: session.start)
    }

    private var rangeLabel: String {
        let cal = Calendar.current
        let fmtTime = DateFormatter()
        fmtTime.dateFormat = "HH:mm"
        let startStr = fmtTime.string(from: session.start)
        let endStr = fmtTime.string(from: session.end)
        if !cal.isDate(session.start, inSameDayAs: session.end) {
            let fmtDay = DateFormatter()
            fmtDay.dateFormat = "MMM d"
            return "\(startStr) → \(fmtDay.string(from: session.end)) \(endStr)"
        }
        return startStr == endStr ? startStr : "\(startStr)–\(endStr)"
    }
}

// MARK: - Git info card (visible in git source mode)

private struct GitInfoCard: View {
    let project: ProjectUsage

    var body: some View {
        let stats = project.gitStats
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GIT HISTORY")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
                    .tracking(0.5)
                Spacer()
                if let stats {
                    Text("\(stats.commitCount) commit\(stats.commitCount == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.mutedForeground)
                        .monospacedDigit()
                }
            }

            if let stats, stats.commitCount > 0 {
                if let last = stats.lastCommit {
                    HStack(spacing: 6) {
                        SourceIcon(source: .git, size: 10)
                            .foregroundStyle(Theme.mutedForeground)
                        Text("Last commit \(TimeFormat.relative(from: last))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.foreground)
                    }
                }
            } else {
                Text(stats == nil
                    ? "Not a git repository (or git unavailable)."
                    : "No commits matched the current filter.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mutedForeground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Calculation note

private struct CalculationNote: View {
    let source: TrackingSource
    let idleGapMinutes: Int
    let gitMaxGapMinutes: Int
    let gitFirstCommitMinutes: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.mutedForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(Theme.muted.opacity(0.5))
        )
    }

    private var text: String {
        switch source {
        case .claude:
            return "Each sitting is a run of messages with no gap longer than \(idleGapMinutes) min. Active time is the wall-clock span of each sitting. Longer gaps split a sitting and are not counted."
        case .git:
            return "Time is estimated from commit timestamps using the git-hours heuristic: gaps shorter than \(gitMaxGapMinutes) min are added to the total; longer gaps start a new session and add \(gitFirstCommitMinutes) min for the first commit."
        }
    }
}
