import Foundation

struct Action: Sendable {
    let cmd: [String]
    let params: [String: AnyCodable]
    let player: String?
    let nextWindow: String?
    let itemsParams: String?

    init(record: [String: Any]) {
        cmd = (record["cmd"] as? [String]) ?? []
        player = Util.string(record, "player")
        nextWindow = Util.string(record, "nextWindow")
        itemsParams = Util.string(record, "itemsParams")
        var p: [String: AnyCodable] = [:]
        if let params = record["params"] as? [String: Any] {
            for (k, v) in params {
                p[k] = AnyCodable(v)
            }
        }
        params = p
    }

    var cmdArray: [String] { cmd }

    func allParams(item: JiveItem? = nil) -> [[String: Any]] {
        var result: [String: Any] = [:]
        for (k, v) in params {
            result[k] = v.value
        }
        return [result]
    }
}

struct AnyCodable: Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }
}

struct SlimCommand: Sendable {
    let player: String?
    let cmd: [String]
    let params: [String: Any]

    init(player: String? = nil, cmd: [String], params: [String: Any] = [:]) {
        self.player = player
        self.cmd = cmd
        self.params = params
    }

    func asCometParams() -> [Any] {
        let playerId = player ?? ""
        var cmdDict: [String: Any] = ["cmd": cmd]
        for (k, v) in params {
            cmdDict[k] = v
        }
        return [playerId, cmd]
    }
}
