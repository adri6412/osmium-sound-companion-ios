import Foundation

// CometD implementation for Lyrion Music Server (HTTP long-polling)
// Channels: /slim/request (one-shot), /slim/subscribe (subscriptions)
// LMS publishes to /<clientId>/slim/serverstatus, /slim/playerstatus/<id>, etc.

@MainActor
final class CometClient: ObservableObject {

    private let session: URLSession
    private var cometURL: URL?
    private var clientId: String?
    private var correlationId: Int = 0
    private var isConnected = false
    private var connectTask: Task<Void, Never>?
    private var channelListeners: [String: [(([String: Any]) -> Void)]] = [:]

    var onServerStatus: (([String: Any]) -> Void)?
    var onPlayerStatus: ((String, [String: Any]) -> Void)?
    var onMenuStatus: ((String, [String: Any]) -> Void)?
    var onDisplayStatus: ((String, [String: Any]) -> Void)?
    var onHandshakeComplete: (([Player]) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    nonisolated init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 70
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func connect(to serverURL: URL, username: String = "", password: String = "") async throws {
        cometURL = serverURL.appendingPathComponent("cometd")
        try await handshake(username: username, password: password)
    }

    func disconnect() {
        connectTask?.cancel()
        connectTask = nil
        isConnected = false
        clientId = nil
        onConnectionChanged?(false)
    }

    // MARK: - Private

    private func handshake(username: String, password: String) async throws {
        guard let cometURL else { throw CometError.notConfigured }

        let handshake: [String: Any] = [
            "channel": "/meta/handshake",
            "version": "1.0",
            "minimumVersion": "1.0beta",
            "supportedConnectionTypes": ["long-polling"],
            "advice": ["timeout": 60000, "interval": 0]
        ]

        let response = try await post(cometURL, messages: [handshake], username: username, password: password)

        guard let first = response.first,
              let successful = first["successful"] as? Bool, successful,
              let cId = first["clientId"] as? String else {
            throw CometError.handshakeFailed
        }

        clientId = cId
        isConnected = true
        onConnectionChanged?(true)

        try await subscribeToServerStatus()
        startPolling()
    }

    private func subscribeToServerStatus() async throws {
        guard let clientId else { return }
        let responseChannel = "/\(clientId)/slim/serverstatus"
        try await subscribe(channel: "/slim/subscribe", response: responseChannel,
                            playerId: "",
                            cmd: ["serverstatus", "0", "255", "subscribe:60"])
    }

    func subscribeToPlayer(_ playerId: String) async throws {
        guard let clientId else { return }
        let playerStatusChannel = "/\(clientId)/slim/playerstatus/\(playerId)"
        try await subscribe(channel: "/slim/subscribe", response: playerStatusChannel,
                            playerId: playerId,
                            cmd: ["status", "-", "255", "menu:menu", "subscribe:30", "tags:aclKNoYLT"])
    }

    private func subscribe(channel: String, response: String,
                           playerId: String = "", cmd: [String]) async throws {
        guard let cometURL, let clientId else { return }
        let msg: [String: Any] = [
            "channel": channel,
            "clientId": clientId,
            "data": [
                "response": response,
                "request": [playerId, cmd] as [Any],
                "clientId": clientId
            ] as [String: Any]
        ]
        _ = try await post(cometURL, messages: [msg])
    }

    // One-shot request to LMS — LMS returns the response in the same HTTP reply
    func request(playerId: String = "", cmd: [String], params: [Any] = []) async throws -> [[String: Any]] {
        guard let cometURL, let clientId else { throw CometError.notConnected }
        correlationId += 1
        let responseChannel = "/\(clientId)/slim/request/\(correlationId)"
        let msg: [String: Any] = [
            "channel": "/slim/request",
            "clientId": clientId,
            "data": [
                "response": responseChannel,
                "request": [playerId, cmd] as [Any],
                "clientId": clientId
            ] as [String: Any]
        ]
        let responses = try await post(cometURL, messages: [msg])
        // LMS echoes the response on responseChannel in the same HTTP reply
        for response in responses {
            if let ch = response["channel"] as? String, ch == responseChannel,
               let data = response["data"] as? [String: Any] {
                return [data]
            }
        }
        // Fallback: any dict under "data"
        return responses.compactMap { $0["data"] as? [String: Any] }
    }

    private func startPolling() {
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func pollLoop() async {
        guard let cometURL, let clientId else { return }
        while !Task.isCancelled && isConnected {
            let connectMsg: [String: Any] = [
                "channel": "/meta/connect",
                "clientId": clientId,
                "connectionType": "long-polling",
                "advice": ["timeout": 60000]
            ]
            do {
                let messages = try await post(cometURL, messages: [connectMsg])
                for msg in messages {
                    await processMessage(msg)
                }
            } catch is CancellationError {
                break
            } catch {
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func processMessage(_ msg: [String: Any]) async {
        guard let channel = msg["channel"] as? String else { return }
        let data = (msg["data"] as? [String: Any]) ?? [:]

        if channel.hasSuffix("/slim/serverstatus") {
            onServerStatus?(data)
        } else if channel.contains("/slim/playerstatus/") {
            let playerId = String(channel.split(separator: "/").last ?? "")
            onPlayerStatus?(playerId, data)
        } else if channel.contains("/slim/menustatus/") {
            let playerId = String(channel.split(separator: "/").last ?? "")
            onMenuStatus?(playerId, data)
        } else if channel.contains("/slim/displaystatus/") {
            let playerId = String(channel.split(separator: "/").last ?? "")
            onDisplayStatus?(playerId, data)
        }

        // Notify generic listeners
        channelListeners[channel]?.forEach { $0(data) }
    }

    func addListener(channel: String, handler: @escaping ([String: Any]) -> Void) {
        channelListeners[channel, default: []].append(handler)
    }

    private func post(_ url: URL, messages: [[String: Any]],
                      username: String = "", password: String = "") async throws -> [[String: Any]] {
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
