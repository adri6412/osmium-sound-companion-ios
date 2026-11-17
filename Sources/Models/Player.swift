import Foundation

final class Player: Identifiable, ObservableObject, @unchecked Sendable {
    let id: String
    var name: String
    let ip: String
    let model: String
    let canPowerOff: Bool
    var connected: Bool
    var playerState: PlayerState

    enum Pref: String, CaseIterable, Sendable {
        case alarmDefaultVolume = "alarmDefaultVolume"
        case alarmFadeSeconds = "alarmfadeseconds"
        case alarmSnoozeSeconds = "alarmSnoozeSeconds"
        case alarmTimeoutSeconds = "alarmTimeoutSeconds"
        case alarmsEnabled = "alarmsEnabled"
        case playTrackAlbum = "playtrackalbum"
        case defeatDestructiveTTP = "defeatDestructiveTouchToPlay"
        case syncVolume = "syncVolume"
        case syncPower = "syncPower"
        case digitalVolumeControl = "digitalVolumeControl"
        case transitionType = "transitionType"
        case transitionDuration = "transitionDuration"
        case replayGainMode = "replayGainMode"
    }

    init(record: [String: Any]) {
        id = Util.string(record, "playerid") ?? ""
        ip = Util.string(record, "ip") ?? ""
        name = Util.string(record, "name") ?? ""
        model = Util.string(record, "model") ?? ""
        canPowerOff = (Util.int(record, "canpoweroff") ?? 0) == 1
        connected = (Util.int(record, "connected") ?? 0) == 1
        playerState = PlayerState()
        for pref in Pref.allCases {
            if let val = Util.string(record, pref.rawValue) {
                playerState.prefs[pref] = val
            }
        }
    }

    var isSyncVolume: Bool {
        playerState.prefs[.syncVolume] == "1"
    }

    var isSynced: Bool {
        playerState.syncMaster != nil || !playerState.syncSlaves.isEmpty
    }
}

extension Player: Equatable {
    static func == (lhs: Player, rhs: Player) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

extension Player: Comparable {
    static func < (lhs: Player, rhs: Player) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
