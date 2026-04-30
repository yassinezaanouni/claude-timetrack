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

                    if let missing = project.missingClaudeData {
                        MissingDataBanner(missing: missing)
                    }

                    StatsRow(project: project)

                    @Bindable var state = state
                    ActivityCalendar(
                        dailyTotals: project.dailyTotals(source: state.trackingSource),
                        selectedDate: $state.selectedDate,
                        accent: Color.paletteColor(for: project.name),
                        title: "ACTIVITY"
                    )

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
        if let day = state.selectedDate {
            SelectedDayHero(project: project, day: day)
        } else {
            defaultStats
        }
    }

    private var defaultStats: some View {
        let claudeAvailable = project.sessionCount > 0
        let gitAvailable = project.commitCount > 0
        let last = project.lastActive(source: state.trackingSource)

        return VStack(spacing: 8) {
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

/// Replaces the 3-box Today/Week/All stat row when the user is drilling into
/// a specific calendar day. Shows that day's per-source totals + a quick way
/// to clear the selection.
private struct SelectedDayHero: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage
    let day: Date

    var body: some View {
        let claude = project.daySeconds(for: day, source: .claude)
        let git = project.daySeconds(for: day, source: .git)
        let active = state.trackingSource == .claude ? claude : git
        let accent = Color.paletteColor(for: project.name)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dayFormatter.string(from: day).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.mutedForeground)
                        .tracking(0.5)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(TimeFormat.short(active))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.foreground)
                            .monospacedDigit()
                        Text(state.trackingSource.label.lowercased())
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { state.selectedDate = nil }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(Theme.mutedForeground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Theme.muted)
                    )
                }
                .buttonStyle(.plain)
                .help("Clear date filter")
            }

            HStack(spacing: 12) {
                miniRow(source: .claude, seconds: claude)
                Divider().frame(height: 18)
                miniRow(source: .git, seconds: git)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func miniRow(source: TrackingSource, seconds: TimeInterval) -> some View {
        HStack(spacing: 5) {
            SourceIcon(source: source, size: 10)
            Text(seconds > 0 ? TimeFormat.short(seconds) : "—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(state.trackingSource == source ? Theme.foreground : Theme.mutedForeground)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()
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

// MARK: - Session list

private struct SessionList: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage

    var body: some View {
        let filtered = filteredSessions
        let title = state.selectedDate != nil ? "SESSIONS ON THIS DAY" : "SESSIONS"

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.mutedForeground)
                    .tracking(0.5)
                Spacer()
                Text("\(filtered.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .monospacedDigit()
            }

            if filtered.isEmpty {
                Text(state.selectedDate != nil
                     ? "No Claude sessions on this day."
                     : "No sessions yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(filtered.prefix(20)) { session in
                        SessionRow(session: session)
                    }
                    if filtered.count > 20 {
                        Text("+ \(filtered.count - 20) older sessions")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    private var filteredSessions: [SessionSummary] {
        guard let day = state.selectedDate else { return project.sessions }
        let cal = Calendar.current
        return project.sessions.filter { cal.isDate($0.start, inSameDayAs: day) }
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

// MARK: - Missing-data banner

/// Surfaced on projects whose `sessions-index.json` references session JSONLs
/// that are no longer on disk — typically because Claude Code pruned them.
/// The Claude time we show for these projects is incomplete.
struct MissingDataBanner: View {
    let missing: MissingClaudeData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Claude data incomplete")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var detail: String {
        let sessions = "\(missing.sessionCount) session\(missing.sessionCount == 1 ? "" : "s")"
        let msgs = missing.messageCount > 0 ? " (~\(missing.messageCount) messages)" : ""
        let range: String = {
            guard let first = missing.earliest, let last = missing.latest else { return "" }
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            let a = f.string(from: first)
            let b = f.string(from: last)
            return a == b ? " from \(a)" : " from \(a) → \(b)"
        }()
        return "\(sessions)\(msgs) referenced in the Claude index but their JSONL files are missing on disk\(range). Claude time shown here is incomplete."
    }
}
