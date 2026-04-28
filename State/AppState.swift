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

    /// Visible projects, filtered + search + hidden + sorted for the selected range.
    func visibleProjects() -> [ProjectUsage] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        var out = projects.filter { !hiddenProjects.contains($0.root) }
        if !q.isEmpty {
            out = out.filter { $0.name.lowercased().contains(q) || $0.root.lowercased().contains(q) }
        }
        out.sort { lhs, rhs in
            let l = lhs.seconds(for: selectedRange, source: trackingSource)
            let r = rhs.seconds(for: selectedRange, source: trackingSource)
            if l != r { return l > r }
            let la = lhs.lastActive(source: trackingSource) ?? .distantPast
            let ra = rhs.lastActive(source: trackingSource) ?? .distantPast
            return la > ra
        }
        if hideInactive && selectedRange != .all {
            out = out.filter { $0.seconds(for: selectedRange, source: trackingSource) > 0 }
        }
        return out
    }

    func totalSeconds(for range: TimeRange) -> TimeInterval {
        projects
            .filter { !hiddenProjects.contains($0.root) }
            .reduce(0) { $0 + $1.seconds(for: range, source: trackingSource) }
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
