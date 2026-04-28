import SwiftUI

/// A clickable time value labeled with its source (Claude or Git). Used in
/// project rows and detail-view stat boxes so the user can compare both
/// numbers side by side and tap the inactive one to swap the global source.
struct TimeChip: View {
    enum Size {
        case row    // compact, used in project rows
        case stat   // taller, used in stat boxes
    }

    let source: TrackingSource
    let active: Bool
    let available: Bool
    let seconds: TimeInterval
    var size: Size = .row
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: { if available && !active { onTap() } }) {
            HStack(alignment: .firstTextBaseline, spacing: spacing) {
                SourceIcon(source: source, size: iconSize)
                Text(available ? TimeFormat.short(seconds) : "—")
                    .font(.system(size: valueSize,
                                  weight: active ? .semibold : .medium,
                                  design: .rounded))
                    .monospacedDigit()
                if active, available, let dayHint = TimeFormat.daysHint(seconds) {
                    Text(dayHint)
                        .font(.system(size: hintSize, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.mutedForeground)
                }
            }
            .foregroundStyle(foregroundColor)
            .contentShape(Rectangle())
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .disabled(!available || active)
        .onHover { hovering = $0 && available && !active }
        .help(active
              ? "Showing \(source.label) time"
              : (available ? "Switch to \(source.label) time" : "No \(source.label) data for this project"))
    }

    private var foregroundColor: Color {
        if active { return Theme.foreground }
        if !available { return Theme.mutedForeground.opacity(0.45) }
        if hovering { return Theme.foreground }
        return Theme.mutedForeground
    }

    private var iconSize: CGFloat {
        switch size {
        case .row:  return active ? 10 : 9
        case .stat: return active ? 11 : 10
        }
    }
    private var valueSize: CGFloat {
        switch size {
        case .row:  return active ? 13 : 11
        case .stat: return active ? 15 : 12
        }
    }
    private var hintSize: CGFloat {
        switch size {
        case .row:  return 9
        case .stat: return 10
        }
    }
    private var spacing: CGFloat {
        switch size {
        case .row:  return 4
        case .stat: return 5
        }
    }
}
