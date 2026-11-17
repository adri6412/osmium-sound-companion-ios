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
            } else if items.isEmpty {
                ContentUnavailableView("Empty", systemImage: "tray")
            } else {
                List {
                    ForEach(items) { child in
                        JiveItemRow(item: child)
                            .onAppear {
                                // Lazy loading
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
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !items.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if let playAction = item.playAction {
                            Button("Play All") {
                                service.doAction(playAction, item: item)
                            }
                        }
                        if let addAction = item.addAction {
                            Button("Add to Queue") {
                                service.doAction(addAction, item: item)
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
