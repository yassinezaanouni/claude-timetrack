import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if state.showSettings {
                    SettingsView()
                } else if let project = state.selectedProject() {
                    ProjectDetailView(project: project)
                } else {
                    MainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 380, height: 540)
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.15), value: state.showSettings)
        .animation(.easeInOut(duration: 0.15), value: state.selectedProjectRoot)
        .onAppear {
            state.refresh()
        }
    }
}
