import Foundation

enum Util {
    static func string(_ record: [String: Any], _ key: String) -> String? {
        if let v = record[key] as? String { return v.isEmpty ? nil : v }
        if let v = record[key] as? Int { return String(v) }
        if let v = record[key] as? Double { return String(v) }
        return nil
    }

    static func int(_ record: [String: Any], _ key: String) -> Int? {
        if let v = record[key] as? Int { return v }
        if let v = record[key] as? String { return Int(v) }
        if let v = record[key] as? Double { return Int(v) }
        return nil
    }

    static func commaSeparated(_ record: [String: Any], _ key: String) -> [String] {
        guard let v = record[key] as? String, !v.isEmpty else { return [] }
        return v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func artworkURL(serverURL: URL, itemId: String?, size: Int = 160) -> URL? {
        guard let itemId, !itemId.isEmpty else { return nil }
        return serverURL.appendingPathComponent("music/\(itemId)/cover_\(size)x\(size)_m.png")
    }

    static func serverArtworkURL(baseURL: URL, path: String) -> URL? {
        guard !path.isEmpty else { return nil }
        if path.hasPrefix("http") { return URL(string: path) }
        return baseURL.appendingPathComponent(path)
    }
}
