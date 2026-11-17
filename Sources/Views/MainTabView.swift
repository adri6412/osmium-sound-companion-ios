import SwiftUI

struct MainTabView: View {
    @Environment(LyrionService.self) private var service
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    private let miniBarGap: CGFloat = 56
    private var miniBarInset: CGFloat { service.activePlayer != nil ? 68 : 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                tab(HomeMenuView())
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                tab(SearchView())
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(1)

                tab(CurrentPlaylistView())
                    .tabItem { Label("Queue", systemImage: "list.bullet") }
                    .tag(2)

                tab(PlayerListView())
                    .tabItem { Label("Players", systemImage: "speaker.wave.3.fill") }
                    .tag(3)

                tab(SettingsView())
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(4)
            }

            if service.activePlayer != nil {
                MiniNowPlayingBar(onTap: { showNowPlaying = true })
                    .padding(.bottom, miniBarGap)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }

    // Keeps scrollable content clear of the mini player floating above the tab bar
    private func tab(_ content: some View) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: miniBarInset)
        }
    }
}
