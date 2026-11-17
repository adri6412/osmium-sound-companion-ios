import Foundation

struct CurrentTrack: Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let albumId: String
    let artworkUrl: String
    let coverId: String
    let duration: Int
    let year: String
    let trackNum: Int
    let bitRate: String
    let sampleRate: Int
    let sampleSize: Int
    let codec: String
    let url: String

    init(record: [String: Any]) {
        id = Util.string(record, "id") ?? ""
        title = Util.string(record, "title") ?? ""
        let trackArtist = Util.string(record, "trackartist")
        let artist_ = Util.string(record, "artist")
        artist = trackArtist ?? artist_ ?? ""
        album = Util.string(record, "album") ?? ""
        albumId = Util.string(record, "album_id") ?? ""
        artworkUrl = Util.string(record, "artwork_url") ?? ""
        coverId = Util.string(record, "coverid") ?? Util.string(record, "artwork_track_id") ?? ""
        duration = Util.int(record, "duration") ?? 0
        year = Util.string(record, "year") ?? ""
        trackNum = Util.int(record, "tracknum") ?? 1
        bitRate = Util.string(record, "bitrate") ?? ""
        sampleRate = Util.int(record, "samplerate") ?? 0
        sampleSize = Util.int(record, "samplesize") ?? 0
        codec = Util.string(record, "type") ?? ""
        url = Util.string(record, "url") ?? ""
    }
}
