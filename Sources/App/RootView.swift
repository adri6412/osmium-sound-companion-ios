import SwiftUI

struct RootView: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        if service.isConnected {
            MainTabView()
        } else {
            ConnectView()
        }
    }
}
