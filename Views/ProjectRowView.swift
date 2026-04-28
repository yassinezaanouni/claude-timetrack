import SwiftUI

struct ProjectRowView: View {
    @Environment(AppState.self) private var state
    let project: ProjectUsage
    let total: TimeInterval

    @State private var isHovering = false

    var body: some View {
        let seconds = project.seconds(for: state.selectedRange)
        let proportion = total > 0 ? seconds / total : 0
        let accent = Color.paletteColor(for: project.name)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let last = project.lastActive {
                        Text(TimeFormat.relative(from: last))
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(TimeFormat.short(seconds))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.foreground)
                    if let dayHint = TimeFormat.daysHint(seconds) {
                        Text(dayHint)
                            .font(.system(size: 9, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }
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
                }
            }
            .frame(height: 4)

            // Hover actions
            if isHovering {
                HStack(spacing: 6) {
                    Text("\(project.sessionCount) session\(project.sessionCount == 1 ? "" : "s")")
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
