import SwiftUI

struct MainTabView: View {
    @Environment(LyrionService.self) private var service
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeMenuView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(1)

                CurrentPlaylistView()
                    .tabItem {
                        Label("Queue", systemImage: "list.bullet")
                    }
                    .tag(2)

                PlayerListView()
                    .tabItem {
                        Label("Players", systemImage: "speaker.wave.3.fill")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }

            // Mini Now Playing bar
            if service.currentTrack != nil {
                MiniNowPlayingBar(onTap: { showNowPlaying = true })
                    .padding(.bottom, 49) // above tab bar
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}
