import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            HeaderView()

            Divider().opacity(0.5)

            SearchBar(text: $state.searchQuery)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ProjectListView()

            Divider().opacity(0.5)

            FooterView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
