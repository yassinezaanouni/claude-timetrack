import Foundation

enum TimeRange: String, CaseIterable, Identifiable, Codable {
    case today
    case week
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .all: return "All time"
        }
    }

    var shortLabel: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .all: return "All"
        }
    }
}
