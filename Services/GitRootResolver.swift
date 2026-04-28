import Foundation

/// Maps an absolute filesystem path (a Claude Code session's cwd) to the nearest
/// ancestor that looks like a project root. Git repos are preferred; otherwise
/// the cwd itself is used. Results are cached per session.
final class GitRootResolver {
    private var cache: [String: String] = [:]
    private let fm = FileManager.default

    func resolve(_ cwd: String) -> String {
        if let cached = cache[cwd] { return cached }

        var url = URL(fileURLWithPath: cwd, isDirectory: true).standardizedFileURL
        var result = url.path
        while true {
            let git = url.appendingPathComponent(".git", isDirectory: false)
            if fm.fileExists(atPath: git.path) {
                result = url.path
                break
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }   // reached /
            url = parent
        }
        cache[cwd] = result
        return result
    }
}
