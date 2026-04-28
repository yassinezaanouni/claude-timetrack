import SwiftUI

struct FooterView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            FooterButton(icon: "arrow.clockwise", label: "Refresh") {
                state.refresh()
            }
            .help("Refresh now")
            .disabled(state.isRefreshing)
            .opacity(state.isRefreshing ? 0.5 : 1.0)

            FooterButton(icon: "gearshape", label: "Settings") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    state.showSettings = true
                }
            }

            Spacer()

            FooterButton(icon: "power", label: "Quit") {
                NSApp.terminate(nil)
            }
            .help("Quit Claude Time Track")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

struct FooterButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(hovering ? Theme.foreground : Theme.mutedForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm)
                    .fill(hovering ? Theme.muted : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
