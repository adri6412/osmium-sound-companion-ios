import Foundation

// CometD implementation for Lyrion Music Server (HTTP long-polling)
// Channels: /slim/request (one-shot), /slim/subscribe (subscriptions)
// LMS publishes to /<clientId>/slim/serverstatus, /slim/playerstatus/<id>, etc.

@MainActor
final class CometClient: ObservableObject {

    private let session: URLSession
    private var cometURL: URL?
    private var username = ""
    private var password = ""
    private var clientId: String?
    private var messageId = 0
    private var isConnected = false
    private var pollTask: Task<Void, Never>?
    private var subscribedPlayerIds: Set<String> = []

    var onServerStatus: (([String: Any]) -> Void)?
    var onPlayerStatus: ((String, [String: Any]) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    nonisolated init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 70
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func connect(to serverURL: URL, username: String = "", password: String = "") async throws {
        cometURL = serverURL.appendingPathComponent("cometd")
        self.username = username
        self.password = password
        subscribedPlayerIds = []
        try await handshake()
        startPolling()
    }

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        isConnected = false
        clientId = nil
        subscribedPlayerIds = []
        onConnectionChanged?(false)
    }

    func subscribeToPlayer(_ playerId: String) async throws {
        subscribedPlayerIds.insert(playerId)
        guard let clientId else { return }
        try await subscribe(response: "/\(clientId)/slim/playerstatus/\(playerId)",
                            playerId: playerId,
                            cmd: ["status", "-", "1", "subscribe:30", LyrionService.playerStatusTags])
    }

    // MARK: - Private

    private func handshake() async throws {
        guard let cometURL else { throw CometError.notConfigured }

        let handshake: [String: Any] = [
            "channel": "/meta/handshake",
            "version": "1.0",
            "minimumVersion": "1.0beta",
            "supportedConnectionTypes": ["long-polling"],
            "advice": ["timeout": 60000, "interval": 0]
        ]

        let response = try await post(cometURL, messages: [handshake])

        guard let first = response.first,
              let successful = first["successful"] as? Bool, successful,
              let cId = first["clientId"] as? String else {
            throw CometError.handshakeFailed
        }

        clientId = cId

        let metaSubscribe: [String: Any] = [
            "channel": "/meta/subscribe",
            "clientId": cId,
            "subscription": "/\(cId)/**"
        ]
        _ = try? await post(cometURL, messages: [metaSubscribe])

        try await subscribe(response: "/\(cId)/slim/serverstatus",
                            playerId: "",
                            cmd: ["serverstatus", "0", "255", "subscribe:60"])
        for playerId in subscribedPlayerIds {
            try await subscribeToPlayer(playerId)
        }

        isConnected = true
        onConnectionChanged?(true)
    }

    private func subscribe(response: String, playerId: String, cmd: [String]) async throws {
        guard let cometURL, let clientId else { return }
        messageId += 1
        let msg: [String: Any] = [
            "channel": "/slim/subscribe",
            "clientId": clientId,
            "id": String(messageId),
            "data": [
                "response": response,
                "request": [playerId, cmd] as [Any]
            ] as [String: Any]
        ]
        // LMS may answer the first result directly in this response instead of on the long-poll.
        for message in try await post(cometURL, messages: [msg]) {
            processMessage(message)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func pollLoop() async {
        while !Task.isCancelled && isConnected {
            guard let cometURL, let clientId else { return }
            let connectMsg: [String: Any] = [
                "channel": "/meta/connect",
                "clientId": clientId,
                "connectionType": "long-polling",
                "advice": ["timeout": 60000]
            ]
            do {
                let messages = try await post(cometURL, messages: [connectMsg])
                var sessionLost = false
                for msg in messages {
                    if msg["channel"] as? String == "/meta/connect", msg["successful"] as? Bool == false {
                        sessionLost = true
                    }
                    processMessage(msg)
                }
                if sessionLost {
                    try await Task.sleep(for: .seconds(2))
                    try await handshake()
                }
            } catch {
                if Task.isCancelled { break }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func processMessage(_ msg: [String: Any]) {
        guard let channel = msg["channel"] as? String,
              let data = msg["data"] as? [String: Any] else { return }

        if channel.hasSuffix("/slim/serverstatus") {
            onServerStatus?(data)
        } else if channel.contains("/slim/playerstatus/") {
            let playerId = String(channel.split(separator: "/").last ?? "")
            onPlayerStatus?(playerId, data)
        }
    }

    private func post(_ url: URL, messages: [[String: Any]]) async throws -> [[String: Any]] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !username.isEmpty {
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: messages)
        let (data, _) = try await session.data(for: request)
        guard let decoded = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return decoded
    }
}

enum CometError: Error {
    case notConfigured
    case notConnected
    case handshakeFailed
}
