import SwiftUI

struct HomeMenuView: View {
    @Environment(LyrionService.self) private var service
    @State private var items: [JiveItem] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView(
                        "Could not load menu",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    List(items) { item in
                        JiveItemRow(item: item)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await loadItems() }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        PlayerListView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                            Text(service.activePlayer?.name ?? "No Player")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .task { await loadItems() }
        .onChange(of: service.activePlayer?.id) { await loadItems() }
    }

    private func loadItems() async {
        isLoading = true
        error = nil
        do {
            items = try await service.fetchHomeMenu()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct JiveItemRow: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        if item.browsable {
            NavigationLink {
                JiveItemListView(title: item.name, item: item)
            } label: {
                JiveItemContent(item: item)
            }
        } else {
            Button {
                if let action = item.doAction ?? item.playAction {
                    service.doAction(action, item: item)
                }
            } label: {
                JiveItemContent(item: item)
            }
            .buttonStyle(.plain)
        }
    }
}

struct JiveItemContent: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        HStack(spacing: 12) {
            if let iconId = item.iconId, let serverURL = service.serverURL {
                AsyncImage(url: Util.artworkURL(serverURL: serverURL, itemId: iconId)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: iconSystemName(item)).foregroundStyle(.secondary)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: iconSystemName(item))
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
            }
        }
    }

    private func iconSystemName(_ item: JiveItem) -> String {
        switch item.type {
        case "playlist": return "music.note.list"
        case "album": return "square.stack"
        case "artist": return "person.fill"
        case "genre": return "music.quarternote.3"
        case "radio": return "antenna.radiowaves.left.and.right"
        default: return "music.note"
        }
    }
}
