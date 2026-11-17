import SwiftUI

struct CurrentPlaylistView: View {
    @Environment(LyrionService.self) private var service
    @State private var songs: [Song] = []
    @State private var total = 0
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && songs.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if songs.isEmpty {
                    ContentUnavailableView("Queue is Empty", systemImage: "music.note.list")
                } else {
                    List {
                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongRow(song: song, index: index)
                                .onAppear {
                                    if song.id == songs.last?.id && songs.count < total {
                                        Task { await loadMore() }
                                    }
                                }
                        }
                        .onMove { from, to in moveSongs(from: from, to: to) }
                        .onDelete { indexSet in deleteSongs(at: indexSet) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                EditButton()
                if !songs.isEmpty {
                    Button(role: .destructive) {
                        Task {
                            service.playlistClear()
                            songs = []
                            total = 0
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .refreshable { await loadPlaylist() }
        }
        .task { await loadPlaylist() }
        .onChange(of: service.activePlayer?.id) { await loadPlaylist() }
    }

    private func loadPlaylist() async {
        isLoading = true
        do {
            let result = try await service.fetchCurrentPlaylist(start: 0)
            songs = result.songs
            total = result.total
        } catch {}
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let result = try await service.fetchCurrentPlaylist(start: songs.count)
            songs.append(contentsOf: result.songs)
        } catch {}
        isLoading = false
    }

    private func moveSongs(from: IndexSet, to: Int) {
        guard let from_ = from.first else { return }
        service.playlistMove(from: from_, to: to > from_ ? to - 1 : to)
        songs.move(fromOffsets: from, toOffset: to)
    }

    private func deleteSongs(at indexSet: IndexSet) {
        for index in indexSet.sorted().reversed() {
            service.playlistRemove(at: index)
            songs.remove(at: index)
        }
    }
}

struct SongRow: View {
    @Environment(LyrionService.self) private var service
    let song: Song
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .lineLimit(1)
                    .bold(service.currentTrack?.id == song.id)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !song.formattedSampleRate.isEmpty {
                Text(song.formattedSampleRate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            service.playlistIndex(index)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
