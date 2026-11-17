import Foundation

enum PlayStatus: String, Sendable {
    case play
    case pause
    case stop
}

enum ShuffleStatus: Int, Sendable {
    case none = 0
    case song = 1
    case album = 2
}

enum RepeatStatus: Int, Sendable {
    case none = 0
    case song = 1
    case playlist = 2
}

struct PlayerState: Sendable {
    var playStatus: PlayStatus = .stop
    var poweredOn: Bool = false
    var shuffleStatus: ShuffleStatus = .none
    var repeatStatus: RepeatStatus = .none
    var currentTrack: CurrentTrack?
    var currentPlaylist: String = ""
    var currentPlaylistTimestamp: Int64 = 0
    var currentPlaylistIndex: Int = -1
    var currentTimeSecond: Double = 0
    var currentTrackDuration: Int = 0
    var currentVolume: Int = 0
    var sleepDuration: Int = 0
    var sleep: Double = 0
    var syncMaster: String?
    var syncSlaves: [String] = []
    var prefs: [Player.Pref: String] = [:]
    var statusSeen: Double = 0

    var isPlaying: Bool { playStatus == .play }
    var isPaused: Bool { playStatus == .pause }
    var isStopped: Bool { playStatus == .stop }

    mutating func update(from record: [String: Any]) {
        if let mode = Util.string(record, "mode") {
            playStatus = PlayStatus(rawValue: mode) ?? .stop
        }
        if let power = Util.int(record, "power") {
            poweredOn = power == 1
        }
        if let shuffle = Util.int(record, "playlist shuffle") {
            shuffleStatus = ShuffleStatus(rawValue: shuffle) ?? .none
        }
        if let repeat_ = Util.int(record, "playlist repeat") {
            repeatStatus = RepeatStatus(rawValue: repeat_) ?? .none
        }
        if let vol = Util.int(record, "mixer volume") {
            currentVolume = vol
        }
        if let time = record["time"] as? Double {
            currentTimeSecond = time
        } else if let time = Util.int(record, "time") {
            currentTimeSecond = Double(time)
        }
        if let duration = record["duration"] as? Double {
            currentTrackDuration = Int(duration)
        } else if let duration = Util.int(record, "duration") {
            currentTrackDuration = duration
        }
        if let sleepVal = record["will_sleep_in"] as? Double {
            sleep = sleepVal
        }
        if let master = Util.string(record, "sync_master") {
            syncMaster = master.isEmpty ? nil : master
        }
        if let slaves = record["sync_slaves"] as? String {
            syncSlaves = slaves.split(separator: ",").map(String.init)
        }
        statusSeen = Date().timeIntervalSince1970
    }
}
