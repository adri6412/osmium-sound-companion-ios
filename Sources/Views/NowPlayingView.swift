import SwiftUI

struct NowPlayingView: View {
    @Environment(LyrionService.self) private var service
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Artwork
                ArtworkView(
                    track: service.currentTrack,
                    serverURL: service.serverURL,
                    size: 320
                )
                .frame(width: 320, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .padding(.bottom, 40)

                // Track info
                VStack(spacing: 6) {
                    Text(service.currentTrack?.title ?? "Not Playing")
                        .font(.title3).bold()
                        .lineLimit(1)
                    Text(service.currentTrack?.artist ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(service.currentTrack?.album ?? "")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Progress
                ProgressBar()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                // Playback controls
                PlaybackControls()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                // Volume
                VolumeSlider()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // Shuffle / Repeat
                ShuffleRepeatRow()
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        CurrentPlaylistView()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
    }
}

struct ProgressBar: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.2)).frame(height: 4)
                    Capsule()
                        .fill(.primary)
                        .frame(width: progressWidth(total: geo.size.width), height: 4)
                }
            }
            .frame(height: 4)
            .gesture(DragGesture().onEnded { value in
                // seek gesture — simplified
            })

            HStack {
                Text(formatTime(service.currentTimeSecond))
                Spacer()
                Text(formatTime(Double(service.currentTrackDuration)))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func progressWidth(total: CGFloat) -> CGFloat {
        guard service.currentTrackDuration > 0 else { return 0 }
        let ratio = service.currentTimeSecond / Double(service.currentTrackDuration)
        return total * min(CGFloat(ratio), 1.0)
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct PlaybackControls: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        HStack(spacing: 40) {
            Button { service.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button { service.togglePausePlay() } label: {
                Image(systemName: service.playStatus == .play ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }

            Button { service.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct VolumeSlider: View {
    @Environment(LyrionService.self) private var service
    @State private var volume: Double = 50

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
            Slider(value: $volume, in: 0...100, step: 1) { editing in
                if !editing {
                    service.setVolume(Int(volume))
                }
            }
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .onAppear { volume = Double(service.currentVolume) }
        .onChange(of: service.currentVolume) { volume = Double(service.currentVolume) }
    }
}

struct ShuffleRepeatRow: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        HStack(spacing: 48) {
            Button { service.toggleShuffle() } label: {
                Image(systemName: service.shuffleStatus == .none ? "shuffle" : "shuffle")
                    .foregroundStyle(service.shuffleStatus != .none ? .blue : .secondary)
            }
            Button { service.toggleRepeat() } label: {
                Image(systemName: service.repeatStatus == .song ? "repeat.1" : "repeat")
                    .foregroundStyle(service.repeatStatus != .none ? .blue : .secondary)
            }
        }
        .font(.title3)
    }
}

struct MiniNowPlayingBar: View {
    @Environment(LyrionService.self) private var service
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(track: service.currentTrack, serverURL: service.serverURL, size: 44)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.currentTrack?.title ?? "")
                        .font(.subheadline).bold()
                        .lineLimit(1)
                    Text(service.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button { service.togglePausePlay() } label: {
                    Image(systemName: service.playStatus == .play ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .padding(.trailing, 4)

                Button { service.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}
