import Foundation

/// Which dataset the UI is currently visualizing.
enum TrackingSource: String, CaseIterable, Identifiable, Codable {
    case claude
    case git

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .git:    return "Git"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "terminal"
        case .git:    return "arrow.triangle.branch"
        }
    }
}
