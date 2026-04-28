import SwiftUI

struct ProjectRowView: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage
    let total: TimeInterval

    @State private var isHovering = false

    var body: some View {
        let activeSource = state.trackingSource
        let activeSeconds = project.seconds(for: state.selectedRange, source: activeSource)
        let proportion = total > 0 ? activeSeconds / total : 0
        let accent = Color.paletteColor(for: project.name)
        let lastActive = project.lastActive(source: activeSource)
        let countLabel = activeSource == .claude
            ? "\(project.sessionCount) session\(project.sessionCount == 1 ? "" : "s")"
            : "\(project.commitCount) commit\(project.commitCount == 1 ? "" : "s")"
        let claudeAvailable = project.sessionCount > 0
        let gitAvailable = (project.gitStats?.commitCount ?? 0) > 0

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let last = lastActive {
                        Text(TimeFormat.relative(from: last))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TimeChip(
                        source: .claude,
                        active: activeSource == .claude,
                        available: claudeAvailable,
                        seconds: project.seconds(for: state.selectedRange, source: .claude),
                        onTap: { switchSource(to: .claude) }
                    )

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mutedForeground.opacity(0.6))

                    TimeChip(
                        source: .git,
                        active: activeSource == .git,
                        available: gitAvailable,
                        seconds: project.seconds(for: state.selectedRange, source: .git),
                        onTap: { switchSource(to: .git) }
                    )
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: activeSource)
            }

            // Proportion bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.muted)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: max(2, geo.size.width * CGFloat(proportion)), height: 4)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: proportion)
                }
            }
            .frame(height: 4)

            // Hover actions
            if isHovering {
                HStack(spacing: 6) {
                    Text(countLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.mutedForeground)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mutedForeground)
                    Text(project.root)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    RowActionButton(icon: "folder", help: "Reveal in Finder") {
                        state.openInFinder(project.root)
                    }
                    RowActionButton(icon: "eye.slash", help: "Hide from list") {
                        state.toggleHidden(project.root)
                    }
                    RowActionButton(icon: "chevron.right", help: "Show breakdown") {
                        state.selectedProjectRoot = project.root
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(isHovering ? Theme.accent : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hover }
            if hover { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture {
            state.selectedProjectRoot = project.root
        }
        .contextMenu {
            Button("Show breakdown") { state.selectedProjectRoot = project.root }
            Button("Reveal in Finder") { state.openInFinder(project.root) }
            Divider()
            Button("Switch to Claude") { switchSource(to: .claude) }
                .disabled(state.trackingSource == .claude)
            Button("Switch to Git") { switchSource(to: .git) }
                .disabled(state.trackingSource == .git)
            Divider()
            Button("Hide project") { state.toggleHidden(project.root) }
        }
    }

    private func switchSource(to source: TrackingSource) {
        guard state.trackingSource != source else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            state.trackingSource = source
        }
    }
}

// MARK: - Time chip

private struct TimeChip: View {
    let source: TrackingSource
    let active: Bool
    let available: Bool
    let seconds: TimeInterval
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: { if available && !active { onTap() } }) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: source.icon)
                    .font(.system(size: active ? 10 : 9, weight: .semibold))
                Text(available ? TimeFormat.short(seconds) : "—")
                    .font(.system(size: active ? 13 : 11,
                                  weight: active ? .semibold : .medium,
                                  design: .rounded))
                    .monospacedDigit()
                if active, let dayHint = TimeFormat.daysHint(seconds), available {
                    Text(dayHint)
                        .font(.system(size: 9, weight: .medium))
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
}

// MARK: - Row action button

private struct RowActionButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hovering ? Theme.foreground : Theme.mutedForeground)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovering ? Theme.muted : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
