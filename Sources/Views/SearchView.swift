import SwiftUI

struct SearchView: View {
    @Environment(LyrionService.self) private var service
    @State private var query = ""
    @State private var results: SearchResults?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView("Search Music", systemImage: "magnifyingglass",
                                          description: Text("Search for albums, artists and tracks"))
                } else if isSearching && results == nil {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let results, !results.isEmpty {
                    resultsList(results)
                } else if !isSearching {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Albums, artists, tracks…")
            .onChange(of: query) { _ in scheduleSearch() }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = nil
            isSearching = false
            return
        }
        isSearching = true
        let q = query
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                let r = try await service.searchLibrary(query: q)
                results = r
            } catch {}
            isSearching = false
        }
    }

    private func resultsList(_ r: SearchResults) -> some View {
        List {
            if !r.albums.isEmpty {
                Section("Albums (\(r.albums.count))") {
                    ForEach(r.albums) { item in
                        NavigationLink {
                            JiveItemListView(title: item.name, item: item)
                        } label: {
                            BrowseItemContent(item: item)
                        }
                        .contextMenu { searchItemMenu(item) }
                    }
                }
            }
            if !r.artists.isEmpty {
                Section("Artists (\(r.artists.count))") {
                    ForEach(r.artists) { item in
                        NavigationLink {
                            JiveItemListView(title: item.name, item: item)
                        } label: {
                            BrowseItemContent(item: item)
                        }
                        .contextMenu { searchItemMenu(item) }
                    }
                }
            }
            if !r.tracks.isEmpty {
                Section("Tracks (\(r.tracks.count))") {
                    ForEach(r.tracks) { item in
                        Button {
                            if let play = item.playAction { service.doAction(play) }
                        } label: {
                            BrowseItemContent(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { searchItemMenu(item) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func searchItemMenu(_ item: JiveItem) -> some View {
        if let play = item.playAction {
            Button { service.doAction(play) } label: { Label("Play Now", systemImage: "play.fill") }
        }
        if let insert = item.insertAction {
            Button { service.doAction(insert) } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
        }
        if let add = item.addAction {
            Button { service.doAction(add) } label: { Label("Add to Queue", systemImage: "text.badge.plus") }
        }
    }
}
