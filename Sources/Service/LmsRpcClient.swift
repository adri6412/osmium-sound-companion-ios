import Foundation

// Synchronous JSON-RPC client for Lyrion Music Server (/jsonrpc.js)
// Use this for all one-shot requests; CometClient handles live subscriptions.
@MainActor
final class LmsRpcClient {

    private let session: URLSession
    private var baseURL: URL?
    private var username: String = ""
    private var password: String = ""

    nonisolated init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func configure(baseURL: URL, username: String = "", password: String = "") {
        self.baseURL = baseURL
        self.username = username
        self.password = password
    }

    func request(playerId: String = "", cmd: [String]) async throws -> [String: Any] {
        guard let baseURL else { throw RpcError.notConfigured }
        let url = baseURL.appendingPathComponent("jsonrpc.js")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !username.isEmpty {
            let creds = Data("\(username):\(password)".utf8).base64EncodedString()
            req.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = ["id": 1, "method": "slim.request", "params": [playerId, cmd]]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else { return [:] }
        return result
    }
}

enum RpcError: Error {
    case notConfigured
}
