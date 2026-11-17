import SwiftUI

struct ArtworkView: View {
    let track: CurrentTrack?
    let serverURL: URL?
    let size: Int

    private var artworkURL: URL? {
        guard let track, let serverURL else { return nil }
        // LMS artwork URL patterns
        if !track.artworkUrl.isEmpty {
            if track.artworkUrl.hasPrefix("http") {
                return URL(string: track.artworkUrl)
            }
            return serverURL.appendingPathComponent(track.artworkUrl)
        }
        if !track.albumId.isEmpty {
            return serverURL.appendingPathComponent("music/\(track.albumId)/cover_\(size)x\(size)_m.png")
        }
        if !track.id.isEmpty {
            return serverURL.appendingPathComponent("music/\(track.id)/cover_\(size)x\(size)_m.png")
        }
        return nil
    }

    var body: some View {
        Group {
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty:
                        placeholder
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.secondary.opacity(0.1))
            Image(systemName: "music.note")
                .font(.system(size: CGFloat(size) / 4))
                .foregroundStyle(.secondary)
        }
    }
}
