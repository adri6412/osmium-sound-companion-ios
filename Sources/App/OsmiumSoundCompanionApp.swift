import SwiftUI

@main
struct OsmiumSoundCompanionApp: App {
    @State private var service = LyrionService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(service)
        }
    }
}
