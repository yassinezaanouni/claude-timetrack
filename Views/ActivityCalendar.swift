import SwiftUI

/// GitHub-style heatmap of daily activity. Reused on the main screen
/// (aggregated across projects) and the detail view (one project).
///
/// Columns are weeks (left = oldest, right = current). Rows are weekdays,
/// Mon at the top through Sun at the bottom.
struct ActivityCalendar: View {
    let dailyTotals: [Date: TimeInterval]
    @Binding var selectedDate: Date?

    /// How many week columns to show. ~26 ≈ six months — comfortable in a
    /// 380pt-wide popover.
    var weeks: Int = 26
    var accent: Color = Theme.primary
    var cell: CGFloat = 9
    var gap: CGFloat = 2
    /// When non-nil, shown above the grid (e.g. "ACTIVITY").
    var title: String? = nil

    var body: some View {
        let grid = Self.buildGrid(weeks: weeks, totals: dailyTotals, today: Date())
        let maxValue = grid.maxValue

        VStack(alignment: .leading, spacing: 6) {
            if let title {
                HStack {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.mutedForeground)
                        .tracking(0.5)
                    Spacer()
                    legend
                }
            }

            HStack(alignment: .top, spacing: 4) {
                weekdayLabels

                HStack(alignment: .top, spacing: gap) {
                    ForEach(grid.cols.indices, id: \.self) { i in
                        VStack(spacing: gap) {
                            ForEach(grid.cols[i].indices, id: \.self) { j in
                                CalendarCell(
                                    cell: grid.cols[i][j],
                                    maxValue: maxValue,
                                    accent: accent,
                                    isSelected: isSelected(grid.cols[i][j].date),
                                    size: cell
                                ) { date in
                                    selectedDate = (selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false)
                                        ? nil
                                        : Calendar.current.startOfDay(for: date)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    private func isSelected(_ date: Date?) -> Bool {
        guard let date, let sel = selectedDate else { return false }
        return Calendar.current.isDate(date, inSameDayAs: sel)
    }

    private var weekdayLabels: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<7, id: \.self) { idx in
                // Show only Mon / Wed / Fri so the gutter stays narrow.
                Text((idx == 0 || idx == 2 || idx == 4) ? Self.weekdayLetter(idx) : " ")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(width: 12, height: cell, alignment: .leading)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 3) {
            Text("less")
                .font(.system(size: 8))
                .foregroundStyle(Theme.mutedForeground)
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.bucketColor(intensity: Double(i) / 4.0, accent: accent))
                    .frame(width: 8, height: 8)
            }
            Text("more")
                .font(.system(size: 8))
                .foregroundStyle(Theme.mutedForeground)
        }
    }

    // MARK: - Grid math

    struct DayCell {
        let date: Date?     // nil = padding cell (future, before grid start)
        let seconds: TimeInterval
    }

    struct Grid {
        let cols: [[DayCell]]   // [week][weekday], 7 cells per col
        let maxValue: TimeInterval
    }

    static func buildGrid(weeks: Int, totals: [Date: TimeInterval], today: Date) -> Grid {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: today)
        let weekday = cal.component(.weekday, from: todayStart)
        // Convert Sunday=1..Saturday=7 → Mon=0..Sun=6
        let monIdx = (weekday + 5) % 7

        let startOfThisWeek = cal.date(byAdding: .day, value: -monIdx, to: todayStart)!
        let firstMonday = cal.date(byAdding: .day, value: -(weeks - 1) * 7, to: startOfThisWeek)!

        var cols: [[DayCell]] = []
        cols.reserveCapacity(weeks)
        var maxValue: TimeInterval = 0

        for w in 0..<weeks {
            var col: [DayCell] = []
            col.reserveCapacity(7)
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: firstMonday)!
                if date > todayStart {
                    col.append(DayCell(date: nil, seconds: 0))
                } else {
                    let secs = totals[date] ?? 0
                    if secs > maxValue { maxValue = secs }
                    col.append(DayCell(date: date, seconds: secs))
                }
            }
            cols.append(col)
        }

        return Grid(cols: cols, maxValue: maxValue)
    }

    static func bucketColor(intensity: Double, accent: Color) -> Color {
        if intensity <= 0 { return Theme.muted }
        if intensity < 0.25 { return accent.opacity(0.30) }
        if intensity < 0.50 { return accent.opacity(0.55) }
        if intensity < 0.75 { return accent.opacity(0.80) }
        return accent
    }

    private static func weekdayLetter(_ monIdx: Int) -> String {
        ["M", "T", "W", "T", "F", "S", "S"][monIdx]
    }
}

// MARK: - Cell

private struct CalendarCell: View {
    let cell: ActivityCalendar.DayCell
    let maxValue: TimeInterval
    let accent: Color
    let isSelected: Bool
    let size: CGFloat
    let onTap: (Date) -> Void

    @State private var hovering = false

    var body: some View {
        let intensity = (maxValue > 0 && cell.seconds > 0) ? cell.seconds / maxValue : 0

        RoundedRectangle(cornerRadius: 2)
            .fill(cell.date == nil ? Color.clear : ActivityCalendar.bucketColor(intensity: intensity, accent: accent))
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(borderColor, lineWidth: isSelected ? 1.2 : (hovering ? 0.8 : 0))
            )
            .scaleEffect(hovering && cell.date != nil ? 1.15 : 1)
            .animation(.easeOut(duration: 0.12), value: hovering)
            .contentShape(Rectangle())
            .onHover { h in if cell.date != nil { hovering = h } }
            .onTapGesture { if let d = cell.date { onTap(d) } }
            .help(tooltip)
    }

    private var borderColor: Color {
        if isSelected { return Theme.foreground }
        if hovering { return Theme.foreground.opacity(0.4) }
        return .clear
    }

    private var tooltip: String {
        guard let date = cell.date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d, yyyy"
        let label = f.string(from: date)
        return cell.seconds > 0
            ? "\(label) — \(TimeFormat.short(cell.seconds))"
            : "\(label) — no activity"
    }
}
