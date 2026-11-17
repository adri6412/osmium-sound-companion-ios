import Foundation

// REST client for the Osmium appliance API (port 8080)
// Used for DSP control, firmware updates, backup/restore, system info
final class ApplianceHttpClient: @unchecked Sendable {

    private let session: URLSession
    private var baseURL: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func configure(baseURL: URL) {
        self.baseURL = baseURL.port == nil
            ? URL(string: "\(baseURL.absoluteString):8080")
            : baseURL
    }

    // MARK: - System Info

    func fetchSystemInfo() async throws -> [String: Any] {
        try await get("api/system")
    }

    func fetchVersion() async throws -> String {
        let info = try await get("api/version")
        return info["version"] as? String ?? ""
    }

    // MARK: - DSP

    func fetchDspSettings() async throws -> [String: Any] {
        try await get("api/dsp/settings")
    }

    func updateDspSettings(_ settings: [String: Any]) async throws {
        _ = try await post("api/dsp/settings", body: settings)
    }

    // MARK: - Audio Output

    func fetchAudioOutputs() async throws -> [[String: Any]] {
        let result = try await get("api/audio/outputs")
        return result["outputs"] as? [[String: Any]] ?? []
    }

    func setAudioOutput(_ outputId: String) async throws {
        _ = try await post("api/audio/output", body: ["id": outputId])
    }

    // MARK: - Backup / Restore

    func fetchBackupInfo() async throws -> [String: Any] {
        try await get("api/backup/info")
    }

    func triggerBackup() async throws {
        _ = try await post("api/backup/create", body: [:])
    }

    // MARK: - Updates

    func fetchUpdateInfo() async throws -> [String: Any] {
        try await get("api/update/status")
    }

    func triggerUpdate() async throws {
        _ = try await post("api/update/apply", body: [:])
    }

    // MARK: - VU Meters

    func fetchVuMeterData() async throws -> [String: Any] {
        try await get("api/vumeter")
    }

    // MARK: - Private

    private func get(_ path: String) async throws -> [String: Any] {
        guard let baseURL else { throw ApplianceError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, _) = try await session.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let baseURL else { throw ApplianceError.notConfigured }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

enum ApplianceError: Error {
    case notConfigured
    case requestFailed(String)
}
