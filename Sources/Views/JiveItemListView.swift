import SwiftUI

struct JiveItemListView: View {
    @Environment(LyrionService.self) private var service
    let title: String
    let item: JiveItem

    @State private var items: [JiveItem] = []
    @State private var isLoading = false
    @State private var totalCount = 0
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView(
                    "Could not load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .refreshable { await loadItems() }
            } else if items.isEmpty && !isLoading {
                ContentUnavailableView("Empty", systemImage: "tray")
                    .refreshable { await loadItems() }
            } else {
                List {
                    ForEach(items) { child in
                        BrowseItemRow(item: child)
                            .onAppear {
                                if child.id == items.last?.id && items.count < totalCount {
                                    Task { await loadMore() }
                                }
                            }
                    }
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadItems() }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let playAction = item.playAction {
                            Button { service.doAction(playAction) } label: {
                                Label("Play All", systemImage: "play.fill")
                            }
                        }
                        if let addAction = item.addAction {
                            Button { service.doAction(addAction) } label: {
                                Label("Add All to Queue", systemImage: "text.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task { await loadItems() }
    }

    private func loadItems() async {
        guard let action = item.goAction else { return }
        isLoading = true
        error = nil
        do {
            let result = try await service.fetchItems(action: action, start: 0)
            items = result.items
            totalCount = result.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard let action = item.goAction, !isLoading else { return }
        isLoading = true
        do {
            let result = try await service.fetchItems(action: action, start: items.count)
            items.append(contentsOf: result.items)
        } catch {}
        isLoading = false
    }
}

// MARK: - Browse Item Row

struct BrowseItemRow: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        Group {
            if item.browsable {
                NavigationLink {
                    JiveItemListView(title: item.name, item: item)
                } label: {
                    BrowseItemContent(item: item)
                }
                .contextMenu { contextMenuButtons }
            } else {
                BrowseItemContent(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap() }
                    .contextMenu { contextMenuButtons }
            }
        }
    }

    private func handleTap() {
        if let play = item.playAction {
            service.doAction(play)
        } else if let doAct = item.doAction {
            service.doAction(doAct)
        }
    }

    @ViewBuilder
    private var contextMenuButtons: some View {
        if let play = item.playAction {
            Button { service.doAction(play) } label: {
                Label("Play", systemImage: "play.fill")
            }
        }
        if let add = item.addAction {
            Button { service.doAction(add) } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }
        }
    }
}

// MARK: - Browse Item Content

struct BrowseItemContent: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        HStack(spacing: 12) {
            // Artwork / icon
            Group {
                if let iconId = item.iconId, let serverURL = service.serverURL {
                    AsyncImage(url: Util.artworkURL(serverURL: serverURL, itemId: iconId, size: 80)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            itemIcon
                        }
                    }
                } else {
                    itemIcon
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var itemIcon: some View {
        ZStack {
            Rectangle().fill(.secondary.opacity(0.1))
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch item.type {
        case "album":    return "square.stack"
        case "artist":   return "person.fill"
        case "genre":    return "music.quarternote.3"
        case "playlist": return "music.note.list"
        case "music":    return "music.note"
        case "radio":    return "antenna.radiowaves.left.and.right"
        case "node":     return "folder.fill"
        default:         return "music.note"
        }
    }
}

// MARK: - Home Menu Row (kept for HomeMenuView backward compat)

struct JiveItemRow: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        BrowseItemRow(item: item)
    }
}

struct JiveItemContent: View {
    @Environment(LyrionService.self) private var service
    let item: JiveItem

    var body: some View {
        BrowseItemContent(item: item)
    }
}
