import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftUI

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

@Observable
final class AppState {

    // MARK: - Data

    var projects: [ProjectUsage] = []
    var isRefreshing: Bool = false
    var lastRefreshedAt: Date? = nil

    // MARK: - UI state (transient)

    var selectedRange: TimeRange = .today
    var showSettings: Bool = false
    var selectedProjectRoot: String? = nil    // nil = list view; non-nil = detail view
    var searchQuery: String = ""
    /// When non-nil, totals/sorts/stats display data for this exact day instead
    /// of the active `selectedRange`. Set by tapping a cell in `ActivityCalendar`.
    var selectedDate: Date? = nil

    /// Resolves the currently-selected project's latest data (or nil).
    func selectedProject() -> ProjectUsage? {
        guard let root = selectedProjectRoot else { return nil }
        return projects.first { $0.root == root }
    }

    // MARK: - Persisted settings

    var idleGapMinutes: Int = UserDefaults.standard.integer(forKey: Keys.idleGap, default: 15) {
        didSet { UserDefaults.standard.set(idleGapMinutes, forKey: Keys.idleGap); refresh() }
    }

    var refreshIntervalSeconds: Int = UserDefaults.standard.integer(forKey: Keys.refresh, default: 60) {
        didSet {
            UserDefaults.standard.set(refreshIntervalSeconds, forKey: Keys.refresh)
            restartTimer()
        }
    }

    var maxProjectsShown: Int = UserDefaults.standard.integer(forKey: Keys.maxShown, default: 12) {
        didSet { UserDefaults.standard.set(maxProjectsShown, forKey: Keys.maxShown) }
    }

    var hideInactive: Bool = UserDefaults.standard.bool(forKey: Keys.hideInactive, default: true) {
        didSet { UserDefaults.standard.set(hideInactive, forKey: Keys.hideInactive) }
    }

    var hiddenProjects: Set<String> = AppState.loadHidden() {
        didSet { AppState.saveHidden(hiddenProjects) }
    }

    var appearanceMode: AppearanceMode = AppearanceMode(
        rawValue: UserDefaults.standard.integer(forKey: Keys.appearance)
    ) ?? .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    var trackingSource: TrackingSource = TrackingSource(
        rawValue: UserDefaults.standard.string(forKey: Keys.source) ?? ""
    ) ?? .claude {
        didSet { UserDefaults.standard.set(trackingSource.rawValue, forKey: Keys.source) }
    }

    var gitMaxGapMinutes: Int = UserDefaults.standard.integer(forKey: Keys.gitGap, default: 120) {
        didSet {
            UserDefaults.standard.set(gitMaxGapMinutes, forKey: Keys.gitGap)
            refresh()
        }
    }

    var gitFirstCommitMinutes: Int = UserDefaults.standard.integer(forKey: Keys.gitFirst, default: 120) {
        didSet {
            UserDefaults.standard.set(gitFirstCommitMinutes, forKey: Keys.gitFirst)
            refresh()
        }
    }

    var gitFilterByEmail: Bool = UserDefaults.standard.bool(forKey: Keys.gitFilter, default: true) {
        didSet {
            UserDefaults.standard.set(gitFilterByEmail, forKey: Keys.gitFilter)
            refresh()
        }
    }

    /// When true, the grand total + bar account for overlapping sessions
    /// across projects (concurrent work counted once instead of per-project).
    /// Per-project numbers and the heatmap stay unchanged.
    var mergeOverlaps: Bool = UserDefaults.standard.bool(forKey: Keys.mergeOverlaps, default: false) {
        didSet { UserDefaults.standard.set(mergeOverlaps, forKey: Keys.mergeOverlaps) }
    }

    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch-at-login error: \(error)")
            }
        }
    }

    // MARK: - Private

    private let tracker = SessionTracker()
    private let gitAnalyzer = GitHistoryAnalyzer()
    private var timer: Timer?

    init() {
        enableLaunchAtLoginOnFirstRun()
        applyAppearance()
        refresh()
        restartTimer()
    }

    func applyAppearance() {
        DispatchQueue.main.async { [appearanceMode] in
            guard let app = NSApp else { return }
            switch appearanceMode {
            case .light:  app.appearance = NSAppearance(named: .aqua)
            case .dark:   app.appearance = NSAppearance(named: .darkAqua)
            case .system: app.appearance = nil
            }
        }
    }

    // MARK: - Actions

    func refresh() {
        // Guard against overlapping refreshes — `GitHistoryAnalyzer` keeps a
        // non-thread-safe cache and concurrent `analyze()` calls have crashed
        // with `_NativeDictionary._copyOrMoveAndResize` aborts.
        guard !isRefreshing else { return }
        isRefreshing = true
        let gap = TimeInterval(max(1, idleGapMinutes) * 60)
        let gitConfig = GitHistoryAnalyzer.Config(
            maxGapMinutes: gitMaxGapMinutes,
            firstCommitMinutes: gitFirstCommitMinutes,
            filterByEmail: gitFilterByEmail
        )
        // SessionTracker is light for ~50 files but we still hop off main to keep UI buttery.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var result = self.tracker.compute(idleGapSeconds: gap)
            // Enrich each project with its git-hours estimate.
            for i in 0..<result.count {
                result[i].gitStats = self.gitAnalyzer.analyze(
                    root: result[i].root, config: gitConfig
                )
            }
            DispatchQueue.main.async {
                self.projects = result
                self.lastRefreshedAt = Date()
                self.isRefreshing = false
            }
        }
    }

    func toggleHidden(_ root: String) {
        if hiddenProjects.contains(root) {
            hiddenProjects.remove(root)
        } else {
            hiddenProjects.insert(root)
        }
    }

    func openInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Visible projects, filtered + search + hidden + sorted for the selected
    /// range *or* the drill-in date when one is set.
    func visibleProjects() -> [ProjectUsage] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        var out = projects.filter { !hiddenProjects.contains($0.root) }
        if !q.isEmpty {
            out = out.filter { $0.name.lowercased().contains(q) || $0.root.lowercased().contains(q) }
        }
        out.sort { lhs, rhs in
            let l = displaySeconds(for: lhs)
            let r = displaySeconds(for: rhs)
            if l != r { return l > r }
            let la = lhs.lastActive(source: trackingSource) ?? .distantPast
            let ra = rhs.lastActive(source: trackingSource) ?? .distantPast
            return la > ra
        }
        // When a specific day is picked, hide projects with no activity that day
        // regardless of the toggle — empty rows would just be noise.
        if selectedDate != nil {
            out = out.filter { displaySeconds(for: $0) > 0 }
        } else if hideInactive && selectedRange != .all {
            out = out.filter { $0.seconds(for: selectedRange, source: trackingSource) > 0 }
        }
        return out
    }

    func totalSeconds(for range: TimeRange) -> TimeInterval {
        projects
            .filter { !hiddenProjects.contains($0.root) }
            .reduce(0) { $0 + $1.seconds(for: range, source: trackingSource) }
    }

    // MARK: - Date drill-in helpers

    /// What every "main number" should show: per-day total when drilling in,
    /// otherwise the active range.
    func displaySeconds(for project: ProjectUsage) -> TimeInterval {
        project.displaySeconds(range: selectedRange, day: selectedDate, source: trackingSource)
    }

    /// Sum of `displaySeconds` across non-hidden projects. When
    /// `mergeOverlaps` is on, returns the de-duplicated wall-clock active
    /// time instead so concurrent work isn't counted twice.
    func displayTotal() -> TimeInterval {
        if mergeOverlaps, trackingSource == .claude {
            return dedupedActiveSeconds()
        }
        return projects
            .filter { !hiddenProjects.contains($0.root) }
            .reduce(0) { $0 + displaySeconds(for: $1) }
    }

    // MARK: - Overlap-aware totals

    /// One session, clipped to the active scope, for timeline rendering.
    struct VisibleSession: Identifiable, Hashable {
        let id: String
        let projectRoot: String
        let projectName: String
        let start: Date
        let end: Date
        /// `activeSeconds / sessionSpan` of the *original* (unclipped) session.
        let rate: Double
    }

    /// The `[start, end)` window the active range covers. For `.all`, derives
    /// from the earliest/latest session timestamps so the timeline has bounds
    /// to plot against.
    func effectiveBound() -> DateInterval? {
        if let day = selectedDate {
            let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
            return DateInterval(start: day, end: next)
        }
        if let interval = selectedRange.interval() { return interval }

        var earliest: Date?
        var latest: Date?
        for p in projects where !hiddenProjects.contains(p.root) {
            for s in p.sessions {
                if earliest == nil || s.start < earliest! { earliest = s.start }
                if latest == nil || s.end > latest! { latest = s.end }
            }
        }
        guard let e = earliest, let l = latest, l > e else { return nil }
        return DateInterval(start: e, end: l)
    }

    /// All Claude sessions across visible projects, clipped to the active
    /// range/day. Returned in arbitrary order. Used by the timeline bar and
    /// the dedup sweep.
    func visibleSessions() -> [VisibleSession] {
        // Clip to the *range* bound, not the synthetic `.all` bound — clipping
        // to the data's own min/max would just be a no-op and waste work.
        let clipBound: DateInterval? = {
            if let day = selectedDate {
                let next = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
                return DateInterval(start: day, end: next)
            }
            return selectedRange.interval()
        }()

        var out: [VisibleSession] = []
        var counter = 0
        for project in projects where !hiddenProjects.contains(project.root) {
            for s in project.sessions {
                let originalSpan = s.end.timeIntervalSince(s.start)
                guard originalSpan > 0 else { continue }
                let rate = min(1, s.activeSeconds / originalSpan)

                var start = s.start
                var end = s.end
                if let b = clipBound {
                    if end <= b.start || start >= b.end { continue }
                    start = max(start, b.start)
                    end = min(end, b.end)
                }
                guard end > start else { continue }

                out.append(VisibleSession(
                    id: "\(s.id)#\(counter)",
                    projectRoot: project.root,
                    projectName: project.name,
                    start: start,
                    end: end,
                    rate: rate
                ))
                counter += 1
            }
        }
        return out
    }

    /// One window of concurrent multi-project work, plus each contributor's
    /// share within it.
    struct OverlapWindow: Identifiable, Hashable {
        let id: String
        let start: Date
        let end: Date
        let entries: [Entry]

        var duration: TimeInterval { end.timeIntervalSince(start) }

        struct Entry: Identifiable, Hashable {
            let id: String
            let projectRoot: String
            let projectName: String
            /// Active seconds this project contributed during this window
            /// (rate-weighted, dedup-capped — see `overlapBreakdown`).
            let activeSeconds: TimeInterval
        }
    }

    /// One project's non-overlapping (solo) active time within scope.
    struct SoloEntry: Identifiable, Hashable {
        let id: String
        let projectRoot: String
        let projectName: String
        let activeSeconds: TimeInterval
    }

    struct OverlapBreakdown {
        let windows: [OverlapWindow]    // chronological, newest last
        let solo: [SoloEntry]           // descending activeSeconds
    }

    /// Walks the visible sessions chronologically and splits them into:
    ///   - **overlap windows**: contiguous intervals where ≥2 projects were
    ///     concurrently active. Each window lists every contributor's share
    ///     of that window's wall-clock time.
    ///   - **solo entries**: per-project totals of time during which only
    ///     that project was active.
    ///
    /// Within each segment the combined activity rate is capped at 1 so
    /// concurrent work isn't counted past wall-clock; each contributor gets
    /// `(rate / totalRate) * cap * dt` of credit.
    func overlapBreakdown() -> OverlapBreakdown {
        let sessions = visibleSessions()
        guard !sessions.isEmpty else { return OverlapBreakdown(windows: [], solo: []) }

        struct Event {
            let time: Date
            let projectRoot: String
            let projectName: String
            let delta: Double
        }

        var events: [Event] = []
        events.reserveCapacity(sessions.count * 2)
        for s in sessions {
            events.append(Event(time: s.start, projectRoot: s.projectRoot, projectName: s.projectName, delta: s.rate))
            events.append(Event(time: s.end, projectRoot: s.projectRoot, projectName: s.projectName, delta: -s.rate))
        }
        events.sort { $0.time < $1.time }

        var rates: [String: Double] = [:]
        var names: [String: String] = [:]

        struct WindowBuilder {
            var start: Date
            var end: Date
            var contribs: [String: TimeInterval] = [:]
        }

        var soloByProject: [String: TimeInterval] = [:]
        var builders: [WindowBuilder] = []

        var i = 0
        var lastTime: Date? = nil
        while i < events.count {
            let t = events[i].time

            if let prev = lastTime {
                let dt = t.timeIntervalSince(prev)
                if dt > 0 {
                    let active = rates.filter { $0.value > 0 }
                    let totalRate = active.values.reduce(0, +)
                    let cap = min(1, totalRate)

                    if active.count == 1, let only = active.first {
                        soloByProject[only.key, default: 0] += cap * dt
                    } else if active.count >= 2 && totalRate > 0 {
                        // Extend the prior window if it ended exactly here, else start new.
                        if !builders.isEmpty, builders[builders.count - 1].end == prev {
                            builders[builders.count - 1].end = t
                            for (root, rate) in active {
                                builders[builders.count - 1].contribs[root, default: 0] += (rate / totalRate) * cap * dt
                            }
                        } else {
                            var b = WindowBuilder(start: prev, end: t)
                            for (root, rate) in active {
                                b.contribs[root, default: 0] += (rate / totalRate) * cap * dt
                            }
                            builders.append(b)
                        }
                    }
                }
            }

            while i < events.count, events[i].time == t {
                let e = events[i]
                rates[e.projectRoot, default: 0] += e.delta
                if e.delta > 0 { names[e.projectRoot] = e.projectName }
                i += 1
            }
            lastTime = t
        }

        let windows: [OverlapWindow] = builders.enumerated().map { idx, b in
            let entries = b.contribs.map { root, secs in
                OverlapWindow.Entry(
                    id: "w\(idx)-\(root)",
                    projectRoot: root,
                    projectName: names[root] ?? root,
                    activeSeconds: secs
                )
            }.sorted { $0.activeSeconds > $1.activeSeconds }

            return OverlapWindow(
                id: "window-\(idx)",
                start: b.start,
                end: b.end,
                entries: entries
            )
        }

        let solo: [SoloEntry] = soloByProject.map { root, secs in
            SoloEntry(
                id: root,
                projectRoot: root,
                projectName: names[root] ?? root,
                activeSeconds: secs
            )
        }
        .filter { $0.activeSeconds > 0 }
        .sorted { $0.activeSeconds > $1.activeSeconds }

        return OverlapBreakdown(windows: windows, solo: solo)
    }

    /// De-duplicated active time across all visible sessions. Each session
    /// contributes activity at rate `activeSeconds / sessionSpan` over its
    /// `[start, end]`. At any instant the combined rate is capped at 1 so
    /// concurrent work doesn't push the total past wall-clock time.
    func dedupedActiveSeconds() -> TimeInterval {
        let sessions = visibleSessions()
        guard !sessions.isEmpty else { return 0 }

        struct Event { let time: Date; let delta: Double }
        var events: [Event] = []
        events.reserveCapacity(sessions.count * 2)
        for s in sessions {
            events.append(Event(time: s.start, delta: s.rate))
            events.append(Event(time: s.end, delta: -s.rate))
        }
        events.sort { $0.time < $1.time }

        var total: TimeInterval = 0
        var rate: Double = 0
        var i = 0
        while i < events.count {
            let t = events[i].time
            while i < events.count, events[i].time == t {
                rate += events[i].delta
                i += 1
            }
            if i < events.count {
                let dt = events[i].time.timeIntervalSince(t)
                total += min(1, rate) * dt
            }
        }
        return total
    }

    /// Aggregate daily totals across non-hidden projects for the active source.
    /// Powers the main-screen activity calendar.
    func combinedDailyTotals() -> [Date: TimeInterval] {
        var out: [Date: TimeInterval] = [:]
        for p in projects where !hiddenProjects.contains(p.root) {
            for (day, secs) in p.dailyTotals(source: trackingSource) {
                out[day, default: 0] += secs
            }
        }
        return out
    }

    /// Tapping a calendar cell. Same date again = clear (toggle).
    func toggleDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        if let cur = selectedDate, Calendar.current.isDate(cur, inSameDayAs: day) {
            selectedDate = nil
        } else {
            selectedDate = day
        }
    }

    // MARK: - Timer

    private func restartTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(15, refreshIntervalSeconds))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - First-run

    private func enableLaunchAtLoginOnFirstRun() {
        let key = "claudetimetrack.didFirstLaunch"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        launchAtLogin = true
    }

    // MARK: - Hidden persistence

    private static func loadHidden() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: Keys.hidden) ?? []
        return Set(arr)
    }

    private static func saveHidden(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: Keys.hidden)
    }

    // MARK: - Keys

    enum Keys {
        static let idleGap = "claudetimetrack.idleGapMinutes"
        static let refresh = "claudetimetrack.refreshIntervalSeconds"
        static let maxShown = "claudetimetrack.maxProjectsShown"
        static let hideInactive = "claudetimetrack.hideInactive"
        static let hidden = "claudetimetrack.hiddenProjects"
        static let appearance = "claudetimetrack.appearanceMode"
        static let source = "claudetimetrack.trackingSource"
        static let gitGap = "claudetimetrack.gitMaxGapMinutes"
        static let gitFirst = "claudetimetrack.gitFirstCommitMinutes"
        static let gitFilter = "claudetimetrack.gitFilterByEmail"
        static let mergeOverlaps = "claudetimetrack.mergeOverlaps"
    }
}

// MARK: - UserDefaults helpers

fileprivate extension UserDefaults {
    func integer(forKey key: String, default fallback: Int) -> Int {
        if object(forKey: key) == nil { return fallback }
        return integer(forKey: key)
    }
    func bool(forKey key: String, default fallback: Bool) -> Bool {
        if object(forKey: key) == nil { return fallback }
        return bool(forKey: key)
    }
}
