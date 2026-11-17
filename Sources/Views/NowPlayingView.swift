import SwiftUI

struct NowPlayingView: View {
    @Environment(LyrionService.self) private var service
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)

                    // Artwork
                    ArtworkView(
                        track: service.currentTrack,
                        serverURL: service.serverURL,
                        size: 400
                    )
                    .frame(width: 300, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(.bottom, 32)

                    // Track info
                    VStack(spacing: 6) {
                        Text(service.currentTrack?.title ?? "Not Playing")
                            .font(.title3).bold()
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                        Text(service.currentTrack?.artist ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(service.currentTrack?.album ?? "")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                        if let info = trackInfoLine {
                            Text(info)
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                    // Progress / Seek
                    SeekBar()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Playback controls
                    PlaybackControls()
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)

                    // Volume
                    VolumeSlider()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                    // Shuffle / Repeat
                    ShuffleRepeatRow()
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                }
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

    private var trackInfoLine: String? {
        guard let track = service.currentTrack else { return nil }
        var parts: [String] = []
        if !track.codec.isEmpty { parts.append(track.codec.uppercased()) }
        if track.sampleRate > 0 {
            let khz = track.sampleRate >= 1000 ? "\(track.sampleRate / 1000)kHz" : "\(track.sampleRate)Hz"
            parts.append(khz)
        }
        if track.sampleSize > 0 { parts.append("\(track.sampleSize)bit") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Seek Bar

struct SeekBar: View {
    @Environment(LyrionService.self) private var service
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var localTime: Double = 0
    @State private var lastServerTime: Double = 0
    @State private var lastServerDate: Date = .now

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: isDragging ? $dragValue : displayTimeBinding,
                in: 0...max(1, Double(service.currentTrackDuration))
            ) { editing in
                isDragging = editing
                if !editing {
                    service.setSeekPosition(Int(dragValue))
                }
            }
            .tint(.primary)

            HStack {
                Text(formatTime(isDragging ? dragValue : localTime))
                Spacer()
                Text(formatTime(Double(service.currentTrackDuration)))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .onReceive(timer) { _ in
            guard !isDragging, service.playStatus == .play else { return }
            let elapsed = Date.now.timeIntervalSince(lastServerDate)
            localTime = min(lastServerTime + elapsed, Double(service.currentTrackDuration))
        }
        .onChange(of: service.currentTimeSecond) {
            lastServerTime = service.currentTimeSecond
            lastServerDate = .now
            localTime = service.currentTimeSecond
        }
        .onAppear {
            lastServerTime = service.currentTimeSecond
            localTime = service.currentTimeSecond
        }
    }

    private var displayTimeBinding: Binding<Double> {
        Binding(get: { localTime }, set: { localTime = $0 })
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        HStack(spacing: 36) {
            Button { service.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button { service.togglePausePlay() } label: {
                Image(systemName: service.playStatus == .play ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
            }

            Button { service.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Volume Slider

struct VolumeSlider: View {
    @Environment(LyrionService.self) private var service
    @State private var volume: Double = 50

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill").foregroundStyle(.secondary).font(.caption)
            Slider(value: $volume, in: 0...100, step: 1) { editing in
                if !editing { service.setVolume(Int(volume)) }
            }
            .tint(.secondary)
            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary).font(.caption)
        }
        .onAppear { volume = Double(service.currentVolume) }
        .onChange(of: service.currentVolume) { volume = Double(service.currentVolume) }
    }
}

// MARK: - Shuffle / Repeat

struct ShuffleRepeatRow: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        HStack(spacing: 48) {
            Button { service.toggleShuffle() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "shuffle")
                        .foregroundStyle(service.shuffleStatus != .none ? .blue : .secondary)
                    if service.shuffleStatus == .album {
                        Text("Album").font(.caption2).foregroundStyle(.blue)
                    }
                }
            }
            Button { service.stop() } label: {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.secondary)
            }
            Button { service.toggleRepeat() } label: {
                Image(systemName: service.repeatStatus == .song ? "repeat.1" : "repeat")
                    .foregroundStyle(service.repeatStatus != .none ? .blue : .secondary)
            }
        }
        .font(.title3)
    }
}

// MARK: - Mini Now Playing Bar

struct MiniNowPlayingBar: View {
    @Environment(LyrionService.self) private var service
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArtworkView(track: service.currentTrack, serverURL: service.serverURL, size: 100)
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
                        .padding(8)
                }
                .buttonStyle(.plain)

                Button { service.nextTrack() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
