import Foundation

struct Alarm: Identifiable, Sendable {
    let id: String
    var time: Int
    var enabled: Bool
    var repeat_: Bool
    var dow: [Int]
    var url: String
    var volume: Int

    init(record: [String: Any]) {
        id = Util.string(record, "id") ?? UUID().uuidString
        time = Util.int(record, "time") ?? 0
        enabled = (Util.int(record, "enabled") ?? 0) == 1
        repeat_ = (Util.int(record, "repeat") ?? 0) == 1
        volume = Util.int(record, "volume") ?? 50
        url = Util.string(record, "url") ?? ""
        if let dowStr = Util.string(record, "dow") {
            dow = dowStr.split(separator: ",").compactMap { Int($0) }
        } else {
            dow = []
        }
    }

    var timeString: String {
        let h = time / 3600
        let m = (time % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }
}

struct AlarmPlaylist: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String

    init(record: [String: Any]) {
        id = Util.string(record, "id") ?? ""
        title = Util.string(record, "title") ?? ""
        category = Util.string(record, "category") ?? ""
    }
}
