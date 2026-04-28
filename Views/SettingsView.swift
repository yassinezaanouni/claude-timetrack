import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        state.showSettings = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Theme.mutedForeground)
                }
                .plainButton()

                Spacer()

                Text("Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.foreground)

                Spacer()

                // balance spacing
                Color.clear.frame(width: 40)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().opacity(0.5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    SettingsCard(title: "General") {
                        ToggleRow(
                            title: "Launch at login",
                            subtitle: "Start Claude Time Track when you log in",
                            isOn: $state.launchAtLogin
                        )
                        Divider().opacity(0.4)
                        ToggleRow(
                            title: "Hide inactive projects",
                            subtitle: "Only show projects with time in the selected range",
                            isOn: $state.hideInactive
                        )
                    }

                    SettingsCard(title: "Tracking") {
                        StepperRow(
                            title: "Idle gap",
                            subtitle: "Gaps longer than this split a sitting and aren't counted",
                            value: $state.idleGapMinutes,
                            range: 1...60,
                            suffix: "min"
                        )
                        Divider().opacity(0.4)
                        StepperRow(
                            title: "Refresh interval",
                            subtitle: "How often the data reloads",
                            value: $state.refreshIntervalSeconds,
                            range: 15...600,
                            step: 15,
                            suffix: "sec"
                        )
                        Divider().opacity(0.4)
                        StepperRow(
                            title: "Max projects shown",
                            subtitle: "Cap on project rows in the list",
                            value: $state.maxProjectsShown,
                            range: 3...40,
                            suffix: "rows"
                        )
                    }

                    if !state.hiddenProjects.isEmpty {
                        SettingsCard(title: "Hidden projects") {
                            VStack(spacing: 6) {
                                ForEach(Array(state.hiddenProjects), id: \.self) { root in
                                    HStack {
                                        Text((root as NSString).lastPathComponent)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.foreground)
                                        Text(root)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Theme.mutedForeground)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Button("Show") {
                                            state.toggleHidden(root)
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.primary)
                                    }
                                }
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Text("Data source: ~/.claude/projects")
                            .font(.system(size: 10, design: .monospaced))
                        Text("ClaudeTimeTrack 1.0")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Theme.mutedForeground)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Card

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mutedForeground)
                .tracking(0.5)
                .padding(.bottom, 6)

            VStack(spacing: 10) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Rows

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.foreground)
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.primary)
        }
    }
}

private struct StepperRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let suffix: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.foreground)
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            HStack(spacing: 6) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus").font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.muted))
                }.plainButton().foregroundStyle(Theme.foreground)

                Text("\(value) \(suffix)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.foreground)
                    .frame(minWidth: 60)

                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.muted))
                }.plainButton().foregroundStyle(Theme.foreground)
            }
        }
    }
}
