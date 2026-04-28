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

    var id: String { root }

    // MARK: - Source-aware accessors

    func seconds(for range: TimeRange) -> TimeInterval {
        switch range {
        case .today: return today
        case .week:  return week
        case .all:   return total
        }
    }

    func seconds(for range: TimeRange, source: TrackingSource) -> TimeInterval {
        switch source {
        case .claude:
            return seconds(for: range)
        case .git:
            guard let g = gitStats else { return 0 }
            switch range {
            case .today: return g.today
            case .week:  return g.week
            case .all:   return g.total
            }
        }
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

    var sessionCount: Int { sessions.count }
    var messageCount: Int { sessions.reduce(0) { $0 + $1.messageCount } }
    var commitCount: Int { gitStats?.commitCount ?? 0 }
}
