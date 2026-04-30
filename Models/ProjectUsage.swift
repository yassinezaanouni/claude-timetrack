import Foundation

/// Git-commit-derived time estimate for a single project, computed via the
/// `git-hours` heuristic (kimmobrunfeldt/git-hours).
struct GitStats: Hashable {
    let total: TimeInterval
    let today: TimeInterval
    let week: TimeInterval
    let dailyTotals: [Date: TimeInterval]
    let lastCommit: Date?
    let commitCount: Int
}

/// Sessions that the project's `sessions-index.json` knows about but whose
/// actual `.jsonl` files no longer exist on disk. This happens when Claude
/// Code (or a cleanup pass) prunes old session files; the index keeps the
/// metadata but the per-message timestamps are gone, so the tracker can't
/// compute their active time.
struct MissingClaudeData: Hashable {
    let sessionCount: Int
    let messageCount: Int
    let earliest: Date?
    let latest: Date?
}

/// Aggregated time statistics for a single project.
///
/// Carries both Claude-derived numbers (sessions/messages) and an optional
/// git-derived estimate (`gitStats`) so views can flip between data sources
/// without re-fetching.
struct ProjectUsage: Identifiable, Hashable {
    let root: String               // absolute path to the project root
    let name: String               // display name (last path component)
    let today: TimeInterval
    let week: TimeInterval
    let total: TimeInterval
    let lastActive: Date?
    let dailyTotals: [Date: TimeInterval]  // last 14 days → seconds (Claude)
    let sessions: [SessionSummary]         // newest first

    /// Populated lazily by `GitHistoryAnalyzer` after Claude-side parsing.
    var gitStats: GitStats? = nil

    /// Set when one or more sessions referenced in `sessions-index.json` are
    /// no longer present on disk; their time can't be tracked.
    var missingClaudeData: MissingClaudeData? = nil

    var id: String { root }

    // MARK: - Source-aware accessors

    func seconds(for range: TimeRange) -> TimeInterval {
        seconds(for: range, source: .claude)
    }

    /// Single source of truth for "how much time in this range from this source?"
    /// Fast paths use the precomputed today/week/total; everything else sums
    /// `dailyTotals` filtered by the range's interval.
    func seconds(for range: TimeRange, source: TrackingSource) -> TimeInterval {
        // Fast paths — match the precomputed fields exactly.
        switch (range, source) {
        case (.today, .claude): return today
        case (.week,  .claude): return week
        case (.all,   .claude): return total
        case (.today, .git):    return gitStats?.today ?? 0
        case (.week,  .git):    return gitStats?.week ?? 0
        case (.all,   .git):    return gitStats?.total ?? 0
        default: break
        }

        // Anything else (yesterday, lastWeek, month, lastMonth) is summed from
        // dailyTotals — DRY: no per-case bookkeeping in the tracker.
        guard let interval = range.interval() else { return 0 }
        var sum: TimeInterval = 0
        for (day, secs) in dailyTotals(source: source) where interval.contains(day) {
            sum += secs
        }
        return sum
    }

    func dailyTotals(source: TrackingSource) -> [Date: TimeInterval] {
        switch source {
        case .claude: return dailyTotals
        case .git:    return gitStats?.dailyTotals ?? [:]
        }
    }

    func lastActive(source: TrackingSource) -> Date? {
        switch source {
        case .claude: return lastActive
        case .git:    return gitStats?.lastCommit
        }
    }

    /// Active time on a specific calendar day (local) for the given source.
    func daySeconds(for date: Date, source: TrackingSource) -> TimeInterval {
        let day = Calendar.current.startOfDay(for: date)
        return dailyTotals(source: source)[day] ?? 0
    }

    /// Single source of truth used by every view: when a day is selected, show
    /// that day's value; otherwise fall back to the active range. Keeps the
    /// drill-in-on-day feature uniform across rows, totals, and stats.
    func displaySeconds(range: TimeRange, day: Date?, source: TrackingSource) -> TimeInterval {
        if let day { return daySeconds(for: day, source: source) }
        return seconds(for: range, source: source)
    }

    var sessionCount: Int { sessions.count }
    var messageCount: Int { sessions.reduce(0) { $0 + $1.messageCount } }
    var commitCount: Int { gitStats?.commitCount ?? 0 }
}
