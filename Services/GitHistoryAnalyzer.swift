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
        let head: String
        let email: String?
        let dates: [Date]   // sorted ascending
    }

    private var cache: [String: CacheEntry] = [:]

    /// User's configured email — read once from `git config --global user.email`.
    private lazy var configuredEmail: String? = {
        Self.runGit(args: ["config", "--global", "user.email"], cwd: nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }()

    /// Returns nil for non-git roots or when `git` is unavailable.
    func analyze(root: String, config: Config, now: Date = Date()) -> GitStats? {
        guard let head = Self.runGit(args: ["rev-parse", "HEAD"], cwd: root)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !head.isEmpty
        else { return nil }

        let email = config.filterByEmail ? configuredEmail : nil

        let dates: [Date]
        if let entry = cache[root], entry.head == head, entry.email == email {
            dates = entry.dates
        } else {
            var args = ["log", "--no-merges", "--pretty=format:%aI"]
            if let email { args.append("--author=\(email)") }
            guard let output = Self.runGit(args: args, cwd: root) else { return nil }
            let parsed = Self.parseDates(output).sorted()
            cache[root] = CacheEntry(head: head, email: email, dates: parsed)
            dates = parsed
        }

        return computeStats(commits: dates, config: config, now: now)
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
