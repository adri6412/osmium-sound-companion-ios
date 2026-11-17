import Foundation

struct Song: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var trackNum: Int
    var artists: [String]
    var artistIds: [String]
    var album: String
    var albumId: String
    var composers: [String]
    var conductors: [String]
    var bands: [String]
    var albumArtists: [String]
    var bitRate: String
    var sampleRate: String
    var duration: Int
    var year: String
    var url: URL?

    init(record: [String: Any]) {
        id = Util.string(record, "id") ?? ""
        title = Util.string(record, "title") ?? ""
        trackNum = Util.int(record, "tracknum") ?? 1
        artists = Util.commaSeparated(record, record["trackartist"] != nil ? "trackartist" : "artist")
        artistIds = Util.commaSeparated(record, record["trackartist_ids"] != nil ? "trackartist_ids" : "artist_ids")
        composers = Util.commaSeparated(record, "composer")
        conductors = Util.commaSeparated(record, "conductor")
        bands = Util.commaSeparated(record, "band")
        albumArtists = Util.commaSeparated(record, "albumartist")
        album = Util.string(record, "album") ?? ""
        albumId = Util.string(record, "album_id") ?? ""
        bitRate = Util.string(record, "bitrate") ?? ""
        sampleRate = Util.string(record, "samplerate") ?? ""
        duration = Util.int(record, "duration") ?? 0
        year = Util.string(record, "year") ?? ""
        if let urlString = Util.string(record, "url") {
            url = URL(string: urlString)
        }
    }

    var artist: String { artists.joined(separator: ", ") }
    var band: String { bands.joined(separator: ", ") }
    var conductor: String { conductors.joined(separator: ", ") }
    var composer: String { composers.joined(separator: ", ") }
    var albumArtist: String { albumArtists.joined(separator: ", ") }

    var formattedSampleRate: String {
        guard let rate = Int(sampleRate), rate > 0 else { return sampleRate }
        let kHz = Double(rate) / 1000.0
        return String(format: kHz == Double(Int(kHz)) ? "%.0f kHz" : "%.1f kHz", kHz)
    }

    var formattedBitRate: String { bitRate == "0" ? "" : bitRate }
}
