import SwiftUI

struct ProjectListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let projects = state.visibleProjects()
        let total = state.totalSeconds(for: state.selectedRange)

        Group {
            if projects.isEmpty {
                EmptyStateView(
                    isFiltered: !state.searchQuery.isEmpty,
                    range: state.selectedRange
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(projects.prefix(state.maxProjectsShown).enumerated()), id: \.1.id) { _, project in
                            ProjectRowView(project: project, total: total)
                        }

                        if projects.count > state.maxProjectsShown {
                            Text("+ \(projects.count - state.maxProjectsShown) more")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mutedForeground)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let isFiltered: Bool
    let range: TimeRange

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isFiltered ? "magnifyingglass" : "moon.stars")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.mutedForeground.opacity(0.5))
            Text(isFiltered ? "No matches" : emptyText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyText: String {
        switch range {
        case .today:     return "No Claude Code activity today yet.\nOpen a session in any project to start tracking."
        case .yesterday: return "No activity yesterday."
        case .week:      return "No activity this week."
        case .lastWeek:  return "No activity last week."
        case .month:     return "No activity this month."
        case .lastMonth: return "No activity last month."
        case .all:       return "No Claude Code sessions found."
        }
    }
}
