import Foundation

/// Aggregated time statistics for a single project, across all Claude Code sessions.
struct ProjectUsage: Identifiable, Hashable {
    let root: String               // absolute path to the project root
    let name: String               // display name (last path component)
    let today: TimeInterval
    let week: TimeInterval
    let total: TimeInterval
    let lastActive: Date?
    let dailyTotals: [Date: TimeInterval]  // last 14 days → seconds
    let sessions: [SessionSummary]         // newest first

    var id: String { root }

    func seconds(for range: TimeRange) -> TimeInterval {
        switch range {
        case .today: return today
        case .week: return week
        case .all: return total
        }
    }

    var sessionCount: Int { sessions.count }
    var messageCount: Int { sessions.reduce(0) { $0 + $1.messageCount } }
}
