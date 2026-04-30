import Foundation

enum TimeRange: String, CaseIterable, Identifiable, Codable {
    case today
    case yesterday
    case week
    case lastWeek
    case month
    case lastMonth
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .week:      return "This week"
        case .lastWeek:  return "Last week"
        case .month:     return "This month"
        case .lastMonth: return "Last month"
        case .all:       return "All time"
        }
    }

    var shortLabel: String {
        switch self {
        case .today:     return "Today"
        case .yesterday: return "Yesterday"
        case .week:      return "Week"
        case .lastWeek:  return "Last wk"
        case .month:     return "Month"
        case .lastMonth: return "Last mo"
        case .all:       return "All"
        }
    }

    /// The 3 cases shown as primary segmented buttons. The remaining ones live
    /// in the "more" menu so the pill stays tight.
    static let primary: [TimeRange] = [.today, .week, .all]
    static let secondary: [TimeRange] = [.yesterday, .lastWeek, .month, .lastMonth]
    var isPrimary: Bool { TimeRange.primary.contains(self) }

    /// The half-open `[start, end)` interval this range covers, in local time,
    /// or `nil` for `.all` (no bound). All filtering downstream goes through
    /// this — single source of truth for "what days does this range include?"
    func interval(reference: Date = Date()) -> DateInterval? {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: reference)

        switch self {
        case .all:
            return nil

        case .today:
            let end = cal.date(byAdding: .day, value: 1, to: startOfToday)!
            return DateInterval(start: startOfToday, end: end)

        case .yesterday:
            let start = cal.date(byAdding: .day, value: -1, to: startOfToday)!
            return DateInterval(start: start, end: startOfToday)

        case .week:
            let start = startOfWeek(containing: startOfToday, calendar: cal)
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            return DateInterval(start: start, end: end)

        case .lastWeek:
            let thisWeekStart = startOfWeek(containing: startOfToday, calendar: cal)
            let start = cal.date(byAdding: .day, value: -7, to: thisWeekStart)!
            return DateInterval(start: start, end: thisWeekStart)

        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: startOfToday))!
            let end = cal.date(byAdding: .month, value: 1, to: start)!
            return DateInterval(start: start, end: end)

        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: startOfToday))!
            let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
            return DateInterval(start: start, end: thisMonthStart)
        }
    }

    /// Monday-aligned start of the week containing `date`, matching the
    /// convention used everywhere else in the app (header, sparkline, sort).
    private func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysSinceMonday = (weekday + 5) % 7  // Sun=1..Sat=7  →  Mon=0..Sun=6
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: date)!
    }
}
