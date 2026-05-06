import Foundation

/// Estimates time spent on a project from its git history using the
/// `git-hours` heuristic (kimmobrunfeldt/git-hours):
///
/// Sort commits by author timestamp. For each consecutive pair, if the gap is
/// ≤ `maxGapMinutes`, add the gap to the total. Otherwise treat it as the
/// boundary of a new coding session and add `firstCommitMinutes` instead.
/// The very first commit also gets `firstCommitMinutes` added (its
/// pre-history is unknown).
final class GitHistoryAnalyzer {

    struct Config: Equatable {
        var maxGapMinutes: Int = 120
        var firstCommitMinutes: Int = 120
        var filterByEmail: Bool = true
    }

    private struct CacheEntry {
        let headMtime: TimeInterval     // mtime of `.git/HEAD` for fast-path
        let head: String                // SHA — secondary key for worktrees
        let email: String?
        let dates: [Date]               // sorted ascending
    }

    /// Concurrent reads/writes are now expected — `AppState.refresh()` runs
    /// `analyze()` in parallel across projects. The lock is held only for
    /// dictionary access; the git invocations happen outside it.
    private var cache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    /// Resolved once at init so parallel `analyze()` calls don't race the
    /// underlying `git config` invocation. Cheap (single short-lived process).
    private let configuredEmail: String?

    init() {
        self.configuredEmail = Self.runGit(args: ["config", "--global", "user.email"], cwd: nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    /// Returns nil for non-git roots or when `git` is unavailable.
    func analyze(root: String, config: Config, now: Date = Date()) -> GitStats? {
        let email = config.filterByEmail ? configuredEmail : nil
        let headMtime = Self.headMtime(for: root)

        // Fast path: HEAD's mtime is unchanged since we last cached this
        // project — skip every git invocation and reuse the parsed dates.
        if let mtime = headMtime,
           let cached = cacheLock.withLock({ cache[root] }),
           cached.headMtime == mtime,
           cached.email == email {
            return computeStats(commits: cached.dates, config: config, now: now)
        }

        // Verify via HEAD SHA. Covers worktrees (where `.git` is a file
        // pointing to the linked git dir, so `.git/HEAD` doesn't exist) and
        // any case where mtime missed the cache for a non-content reason.
        guard let head = Self.runGit(args: ["rev-parse", "HEAD"], cwd: root)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !head.isEmpty
        else { return nil }

        let cachedBySha = cacheLock.withLock { cache[root] }
        if let cachedBySha, cachedBySha.head == head, cachedBySha.email == email {
            // SHA matches — refresh stored mtime so next refresh hits the
            // cheap path even if mtime previously skipped (e.g. worktree).
            if let mtime = headMtime, mtime != cachedBySha.headMtime {
                let refreshed = CacheEntry(
                    headMtime: mtime,
                    head: head,
                    email: email,
                    dates: cachedBySha.dates
                )
                cacheLock.withLock { cache[root] = refreshed }
            }
            return computeStats(commits: cachedBySha.dates, config: config, now: now)
        }

        // Full miss — run `git log`.
        var args = ["log", "--no-merges", "--pretty=format:%aI"]
        if let email { args.append("--author=\(email)") }
        guard let output = Self.runGit(args: args, cwd: root) else { return nil }
        let dates = Self.parseDates(output).sorted()

        let entry = CacheEntry(
            headMtime: headMtime ?? 0,
            head: head,
            email: email,
            dates: dates
        )
        cacheLock.withLock { cache[root] = entry }

        return computeStats(commits: dates, config: config, now: now)
    }

    private static func headMtime(for root: String) -> TimeInterval? {
        let path = "\(root)/.git/HEAD"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let date = attrs[.modificationDate] as? Date
        else { return nil }
        return date.timeIntervalSince1970
    }

    // MARK: - Algorithm

    private func computeStats(commits: [Date], config: Config, now: Date) -> GitStats {
        guard !commits.isEmpty else {
            return GitStats(total: 0, today: 0, week: 0,
                            dailyTotals: [:], lastCommit: nil, commitCount: 0)
        }
        let maxGap = TimeInterval(max(1, config.maxGapMinutes) * 60)
        let firstAdd = TimeInterval(max(1, config.firstCommitMinutes) * 60)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let weekdayIndex = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekdayIndex + 5) % 7
        let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday,
                                        to: startOfToday) ?? startOfToday

        var total: TimeInterval = 0
        var today: TimeInterval = 0
        var week: TimeInterval = 0
        var daily: [Date: TimeInterval] = [:]

        for (i, date) in commits.enumerated() {
            let delta: TimeInterval
            if i == 0 {
                delta = firstAdd
            } else {
                let gap = date.timeIntervalSince(commits[i - 1])
                delta = gap < maxGap ? gap : firstAdd
            }
            total += delta
            if date >= startOfToday { today += delta }
            if date >= startOfWeek  { week  += delta }
            let day = calendar.startOfDay(for: date)
            daily[day, default: 0] += delta
        }

        return GitStats(
            total: total,
            today: today,
            week: week,
            dailyTotals: daily,
            lastCommit: commits.last,
            commitCount: commits.count
        )
    }

    // MARK: - Helpers

    private static func parseDates(_ output: String) -> [Date] {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        var out: [Date] = []
        out.reserveCapacity(1024)
        output.enumerateLines { line, _ in
            let s = line.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return }
            if let d = plain.date(from: s) ?? withFrac.date(from: s) {
                out.append(d)
            }
        }
        return out
    }

    private static func runGit(args: [String], cwd: String?) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        var argv = ["git"]
        if let cwd { argv.append(contentsOf: ["-C", cwd]) }
        argv.append(contentsOf: args)
        process.arguments = argv

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
