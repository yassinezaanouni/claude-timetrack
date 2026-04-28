import Foundation

/// A single timestamped message from a Claude Code JSONL session file.
struct SessionEvent {
    let timestamp: Date
    let projectRoot: String    // resolved (git root when available, else cwd)
    let sessionId: String
    let jsonlPath: String
}

/// One Claude Code session, aggregated for display.
struct SessionSummary: Identifiable, Hashable {
    let id: String              // sessionId
    let projectRoot: String
    let jsonlPath: String
    let start: Date             // first message timestamp
    let end: Date               // last message timestamp
    let activeSeconds: TimeInterval   // sum of gaps ≤ idle threshold
    let messageCount: Int             // number of timestamped events
    let droppedIdleSeconds: TimeInterval  // sum of gaps > idle (skipped)
}
