import Foundation

/// Scans ~/.claude/projects/**/*.jsonl and computes per-project active time.
///
/// "Active time" = sum of gaps between consecutive timestamped messages in the
/// same project, excluding any gap longer than `idleGapSeconds` (treated as
/// idle). Results are cached per file by (mtime, size) so re-reads are cheap.
final class SessionTracker {

    struct FileCacheEntry {
        let mtime: TimeInterval
        let size: Int
        let events: [SessionEvent]
    }

    private var fileCache: [String: FileCacheEntry] = [:]
    private let resolver = GitRootResolver()
    private let fm = FileManager.default

    let projectsURL: URL

    init(projectsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)) {
        self.projectsURL = projectsURL
    }

    /// Returns all projects with per-session breakdowns.
    ///
    /// A Claude Code JSONL file can be *resumed* across multiple days, so one
    /// file != one "session" from the user's perspective. We therefore split
    /// each file's events into contiguous sittings whenever an idle gap is
    /// encountered — each sitting becomes its own `SessionSummary`.
    func compute(idleGapSeconds: TimeInterval = 900, now: Date = Date()) -> [ProjectUsage] {
        let events = refreshCacheAndCollectEvents()
        guard !events.isEmpty else { return [] }

        // Group events by the *file* (sessionId from the JSONL) first, so we
        // split within a file rather than across unrelated files.
        var byFile: [String: [SessionEvent]] = [:]
        for e in events {
            byFile[e.sessionId, default: []].append(e)
        }

        var sessionSummaries: [SessionSummary] = []
        for (sid, evts) in byFile {
            let sorted = evts.sorted { $0.timestamp < $1.timestamp }
            // Break into sittings on idle gaps
            var sittingStartIdx = 0
            var active: TimeInterval = 0
            var sittingMessages = 1
            var counter = 0

            func flush(endIdx: Int) {
                guard endIdx >= sittingStartIdx else { return }
                let start = sorted[sittingStartIdx].timestamp
                let end = sorted[endIdx].timestamp
                sessionSummaries.append(
                    SessionSummary(
                        id: "\(sid)#\(counter)",
                        projectRoot: sorted[sittingStartIdx].projectRoot,
                        jsonlPath: sorted[sittingStartIdx].jsonlPath,
                        start: start,
                        end: end,
                        activeSeconds: active,
                        messageCount: sittingMessages,
                        droppedIdleSeconds: 0   // per-sitting; cross-sitting gaps aren't attributed here
                    )
                )
            }

            for i in 0..<(sorted.count - 1) {
                let gap = sorted[i + 1].timestamp.timeIntervalSince(sorted[i].timestamp)
                if gap > idleGapSeconds {
                    // End current sitting at i
                    flush(endIdx: i)
                    counter += 1
                    sittingStartIdx = i + 1
                    active = 0
                    sittingMessages = 1
                } else if gap > 0 {
                    active += gap
                    sittingMessages += 1
                } else {
                    sittingMessages += 1
                }
            }
            // Flush the last sitting
            flush(endIdx: sorted.count - 1)
        }

        // Group sessions by project root
        var byProject: [String: [SessionSummary]] = [:]
        for s in sessionSummaries {
            byProject[s.projectRoot, default: []].append(s)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let weekdayIndex = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekdayIndex + 5) % 7
        let startOfWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfToday) ?? startOfToday

        var results: [ProjectUsage] = []
        results.reserveCapacity(byProject.count)

        for (root, projSessions) in byProject {
            let sortedSessions = projSessions.sorted { $0.end > $1.end }

            var total: TimeInterval = 0
            var today: TimeInterval = 0
            var week: TimeInterval = 0
            var daily: [Date: TimeInterval] = [:]
            var lastActive: Date?

            for s in projSessions {
                total += s.activeSeconds
                if s.end >= startOfToday { today += s.activeSeconds }
                if s.end >= startOfWeek { week += s.activeSeconds }

                // Bucket each session into the local day of its END timestamp.
                // (Simple and good enough for a 14-day sparkline.)
                let day = calendar.startOfDay(for: s.end)
                daily[day, default: 0] += s.activeSeconds

                if lastActive == nil || s.end > lastActive! {
                    lastActive = s.end
                }
            }

            let name = (root as NSString).lastPathComponent
            results.append(
                ProjectUsage(
                    root: root,
                    name: name.isEmpty ? root : name,
                    today: today,
                    week: week,
                    total: total,
                    lastActive: lastActive,
                    dailyTotals: daily,
                    sessions: sortedSessions
                )
            )
        }

        // Attach missing-data warnings, and synthesize stub projects for any
        // project that has only missing sessions (no surviving JSONLs).
        let missingMap = collectMissingData()
        if !missingMap.isEmpty {
            var byRoot = Dictionary(uniqueKeysWithValues: results.map { ($0.root, $0) })
            for (root, data) in missingMap {
                if var existing = byRoot[root] {
                    existing.missingClaudeData = data
                    byRoot[root] = existing
                } else {
                    let name = (root as NSString).lastPathComponent
                    byRoot[root] = ProjectUsage(
                        root: root,
                        name: name.isEmpty ? root : name,
                        today: 0, week: 0, total: 0,
                        lastActive: data.latest,
                        dailyTotals: [:],
                        sessions: [],
                        missingClaudeData: data
                    )
                }
            }
            results = Array(byRoot.values)
        }

        return results
    }

    // MARK: - Private

    private func refreshCacheAndCollectEvents() -> [SessionEvent] {
        guard let enumerator = try? fm.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        var all: [SessionEvent] = []
        var seen: Set<String> = []

        for projectDir in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            guard let files = try? fm.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let path = file.path
                seen.insert(path)

                guard let attrs = try? fm.attributesOfItem(atPath: path),
                      let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970,
                      let size = attrs[.size] as? Int else { continue }

                if let cached = fileCache[path], cached.mtime == mtime, cached.size == size {
                    all.append(contentsOf: cached.events)
                    continue
                }

                let events = parseFile(at: file)
                fileCache[path] = FileCacheEntry(mtime: mtime, size: size, events: events)
                all.append(contentsOf: events)
            }
        }

        for key in fileCache.keys where !seen.contains(key) {
            fileCache.removeValue(forKey: key)
        }

        return all
    }

    // MARK: - Missing-data scan

    /// Decoded shape of `~/.claude/projects/<encoded-cwd>/sessions-index.json`.
    /// Only the fields we actually use are listed.
    private struct SessionsIndex: Decodable {
        struct Entry: Decodable {
            let fullPath: String
            let projectPath: String?
            let messageCount: Int?
            let created: String?
            let modified: String?
        }
        let entries: [Entry]
    }

    /// For every project folder, read `sessions-index.json` and identify
    /// entries whose `.jsonl` no longer exists. Group counts/messages/dates by
    /// the resolved git root so we can attach a single summary per project.
    private func collectMissingData() -> [String: MissingClaudeData] {
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: projectsURL, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [:] }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]
        func parseDate(_ s: String?) -> Date? {
            guard let s, !s.isEmpty else { return nil }
            return isoFrac.date(from: s) ?? isoPlain.date(from: s)
        }

        var bucket: [String: (count: Int, msgs: Int, earliest: Date?, latest: Date?)] = [:]

        for dir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let indexURL = dir.appendingPathComponent("sessions-index.json")
            guard let data = try? Data(contentsOf: indexURL),
                  let idx = try? JSONDecoder().decode(SessionsIndex.self, from: data)
            else { continue }

            for entry in idx.entries {
                guard !fm.fileExists(atPath: entry.fullPath) else { continue }
                // projectPath in the index is the original cwd; resolve it to a git
                // root so this groups under the same key as live JSONLs do.
                guard let cwd = entry.projectPath else { continue }
                let root = resolver.resolve(cwd)
                let created = parseDate(entry.created)
                let modified = parseDate(entry.modified)
                var b = bucket[root] ?? (count: 0, msgs: 0, earliest: nil, latest: nil)
                b.count += 1
                b.msgs += entry.messageCount ?? 0
                if let c = created { b.earliest = b.earliest.map { min($0, c) } ?? c }
                if let m = modified { b.latest = b.latest.map { max($0, m) } ?? m }
                bucket[root] = b
            }
        }

        return bucket.mapValues {
            MissingClaudeData(
                sessionCount: $0.count,
                messageCount: $0.msgs,
                earliest: $0.earliest,
                latest: $0.latest
            )
        }
    }

    private func parseFile(at url: URL) -> [SessionEvent] {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return [] }

        let jsonlPath = url.path
        var out: [SessionEvent] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]

        // Fallback session id = filename stem (session UUID is the filename).
        let fileSessionId = url.deletingPathExtension().lastPathComponent

        text.enumerateLines { line, _ in
            guard !line.isEmpty else { return }
            guard let lineData = line.data(using: .utf8) else { return }
            guard let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { return }
            guard let ts = obj["timestamp"] as? String,
                  let cwd = obj["cwd"] as? String else { return }

            let date = iso.date(from: ts) ?? isoNoFrac.date(from: ts)
            guard let date else { return }

            let sessionId = (obj["sessionId"] as? String) ?? fileSessionId
            let root = self.resolver.resolve(cwd)
            out.append(SessionEvent(
                timestamp: date,
                projectRoot: root,
                sessionId: sessionId,
                jsonlPath: jsonlPath
            ))
        }

        return out
    }
}
