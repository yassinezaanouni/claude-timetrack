import Foundation

enum TimeFormat {

    /// Short, human-scannable. Hours are always primary; days never replace them.
    /// "0m", "12m", "1h 23m", "10h", "51h", "181h".
    static func short(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let mm = m % 60
        if h < 10 && mm > 0 { return "\(h)h \(mm)m" }
        return "\(h)h"
    }

    /// Optional secondary day hint to pair with `short(...)` for large values.
    /// Returns nil under 24h. Output: "~1d", "~2.1d", "~8d".
    static func daysHint(_ seconds: TimeInterval) -> String? {
        let h = seconds / 3600
        guard h >= 24 else { return nil }
        let d = h / 24
        if d < 10 { return String(format: "~%.1fd", d) }
        return "~\(Int(d.rounded()))d"
    }

    /// Compact for the menu bar (single token, always ≤ 6 chars).
    static func menuBar(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "0m" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        let h = Double(s) / 3600.0
        if h < 10 { return String(format: "%.1fh", h) }
        return "\(Int(h.rounded()))h"
    }

    /// Relative time since a date ("3m ago", "just now", "2d ago").
    static func relative(from date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let m = Int(seconds / 60)
        if m < 60 { return "\(m)m ago" }
        let h = m / 60
        if h < 24 { return "\(h)h ago" }
        let d = h / 24
        if d < 7 { return "\(d)d ago" }
        let w = d / 7
        return "\(w)w ago"
    }
}
