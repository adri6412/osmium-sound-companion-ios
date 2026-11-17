import Foundation

struct JiveItem: Identifiable, Sendable {
    let id: String
    let name: String
    let type: String?
    let icon: String?
    let iconId: String?
    let weight: Int
    var goAction: Action?
    var doAction: Action?
    var moreAction: Action?
    var playAction: Action?
    var addAction: Action?
    var input: InputSpec?
    var hasSubItems: Bool
    var isANode: Bool

    init(record: [String: Any]) {
        id = Util.string(record, "id") ?? UUID().uuidString
        name = Util.string(record, "name") ?? Util.string(record, "title") ?? ""
        type = Util.string(record, "type")
        icon = Util.string(record, "icon")
        iconId = Util.string(record, "iconId")
        weight = Util.int(record, "weight") ?? 0
        hasSubItems = (Util.int(record, "hasSubItems") ?? 0) == 1
        isANode = type == "node"

        if let actions = record["actions"] as? [String: Any] {
            if let go = actions["go"] as? [String: Any] {
                goAction = Action(record: go)
            }
            if let doAct = actions["do"] as? [String: Any] {
                doAction = Action(record: doAct)
            }
            if let more = actions["more"] as? [String: Any] {
                moreAction = Action(record: more)
            }
            if let play = actions["play"] as? [String: Any] {
                playAction = Action(record: play)
            }
            if let add = actions["add"] as? [String: Any] {
                addAction = Action(record: add)
            }
        }

        if let inputSpec = record["input"] as? [String: Any] {
            input = InputSpec(record: inputSpec)
        }
    }

    var browsable: Bool { goAction != nil || hasSubItems }
    var playable: Bool { playAction != nil || doAction != nil }
}

struct InputSpec: Sendable {
    let len: Int
    let title: String
    let allowedChars: String?
    let processesAs: String?

    init(record: [String: Any]) {
        len = Util.int(record, "len") ?? 0
        title = Util.string(record, "title") ?? ""
        allowedChars = Util.string(record, "allowedchars")
        processesAs = Util.string(record, "processingAs")
    }
}
