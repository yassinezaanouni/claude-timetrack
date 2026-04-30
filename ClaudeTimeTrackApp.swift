import SwiftUI

@main
struct ClaudeTimeTrackApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(appState)
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar title — icon + compact total for the selected range.
/// Reads AppState directly so it redraws when totals or range change.
private struct MenuBarLabel: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
            Text(rangePrefix + TimeFormat.menuBar(appState.totalSeconds(for: appState.selectedRange)))
                .monospacedDigit()
        }
    }

    private var rangePrefix: String {
        switch appState.selectedRange {
        case .today:     return ""
        case .yesterday: return "Y "
        case .week:      return "W "
        case .lastWeek:  return "LW "
        case .month:     return "M "
        case .lastMonth: return "LM "
        case .all:       return "∑ "
        }
    }
}
