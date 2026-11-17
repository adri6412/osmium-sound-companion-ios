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
                } else if let error, items.isEmpty {
                    ContentUnavailableView(
                        "Could not load menu",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .refreshable { await loadItems() }
                } else {
                    List(items) { item in
                        BrowseItemRow(item: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await loadItems() }
                }
            }
            .navigationTitle("My Music")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        PlayerListView()
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(service.isConnected ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(service.activePlayer?.name ?? "No Player")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .task { await loadItems() }
        .onChange(of: service.activePlayer?.id) { _ in Task { await loadItems() } }
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
