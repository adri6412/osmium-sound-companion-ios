import Foundation

@MainActor
@Observable
final class LyrionService {

    // Connection state
    var isConnected = false
    var isConnecting = false
    var connectionError: String?

    // Server
    var serverURL: URL?
    var serverVersion: String = ""

    // Players
    var players: [Player] = []
    var activePlayer: Player?

    // Current playback (mirrors activePlayer.playerState for convenience)
    var currentTrack: CurrentTrack?
    var playStatus: PlayStatus = .stop
    var currentVolume: Int = 0
    var shuffleStatus: ShuffleStatus = .none
    var repeatStatus: RepeatStatus = .none
    var currentTimeSecond: Double = 0
    var currentTrackDuration: Int = 0

    private let comet = CometClient()
    private let rpc = LmsRpcClient()
    private let applianceClient = ApplianceHttpClient()
    private var connectTask: Task<Void, Never>?

    init() {
        setupCometCallbacks()
    }

    // MARK: - Connection

    func connect(host: String, port: Int = 9000, username: String = "", password: String = "") {
        guard !isConnecting else { return }
        guard let url = URL(string: "http://\(host):\(port)") else {
            connectionError = "Invalid server address"
            return
        }
        serverURL = url
        rpc.configure(baseURL: url, username: username, password: password)
        isConnecting = true
        connectionError = nil
        connectTask = Task {
            do {
                try await comet.connect(to: url, username: username, password: password)
                // Load initial server status synchronously via JSON-RPC
                await self.loadInitialServerStatus()
            } catch {
                self.isConnecting = false
                self.connectionError = error.localizedDescription
            }
        }
    }

    func disconnect() {
        connectTask?.cancel()
        comet.disconnect()
        isConnected = false
        isConnecting = false
        players = []
        activePlayer = nil
        currentTrack = nil
        playStatus = .stop
    }

    // MARK: - Player Control

    func setActivePlayer(_ player: Player) {
        activePlayer = player
        Task { try? await comet.subscribeToPlayer(player.id) }
        syncFromActivePlayer()
    }

    func togglePausePlay() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["pause"]) }
    }

    func nextTrack() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "index", "+1"]) }
    }

    func previousTrack() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "index", "-1"]) }
    }

    func stop() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["stop"]) }
    }

    func setVolume(_ volume: Int, player: Player? = nil) {
        let p = player ?? activePlayer
        guard let p else { return }
        Task { try? await sendPlayerCommand(player: p.id, cmd: ["mixer", "volume", "\(volume)"]) }
    }

    func adjustVolume(_ direction: Int) {
        guard let player = activePlayer else { return }
        let sign = direction > 0 ? "+" : ""
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["mixer", "volume", "\(sign)\(direction)"]) }
    }

    func toggleMute(player: Player? = nil) {
        let p = player ?? activePlayer
        guard let p else { return }
        Task { try? await sendPlayerCommand(player: p.id, cmd: ["mixer", "muting", "toggle"]) }
    }

    func toggleShuffle() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "shuffle"]) }
    }

    func toggleRepeat() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "repeat"]) }
    }

    func setSeekPosition(_ seconds: Int) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["time", "\(seconds)"]) }
    }

    func togglePower(player: Player) {
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["power"]) }
    }

    func setPlayerPref(player: Player, pref: Player.Pref, value: String) {
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playerpref", pref.rawValue, value]) }
    }

    func syncPlayer(_ player: Player, toMaster masterId: String) {
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["sync", masterId]) }
    }

    func unsyncPlayer(_ player: Player) {
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["sync", "-"]) }
    }

    // MARK: - Browse

    func fetchItems(action: Action, start: Int = 0, count: Int = 100) async throws -> (items: [JiveItem], total: Int) {
        guard let player = activePlayer else { return ([], 0) }
        let cmd = action.cmd
        if cmd.isEmpty { return ([], 0) }
        let data = try await rpc.request(playerId: player.id, cmd: cmd)
        return parseJiveItems(from: data)
    }

    func fetchHomeMenu() async throws -> [JiveItem] {
        let data = try await rpc.request(cmd: ["menu", "0", "100", "menu:menu"])
        let (items, _) = parseJiveItems(from: data)
        return items
    }

    func fetchCurrentPlaylist(start: Int = 0) async throws -> (songs: [Song], total: Int) {
        guard let player = activePlayer else { return ([], 0) }
        let data = try await rpc.request(playerId: player.id,
                                         cmd: ["status", "\(start)", "100", "tags:aclKNoYLT"])
        let loop = (data["playlist_loop"] as? [[String: Any]]) ?? []
        let songs = loop.map { Song(record: $0) }
        let total = Util.int(data, "playlist_tracks") ?? songs.count
        return (songs, total)
    }

    func fetchAlbums(start: Int = 0) async throws -> [JiveItem] {
        let data = try await rpc.request(cmd: ["albums", "\(start)", "100", "tags:lajKAS"])
        let (items, _) = parseJiveItems(from: data)
        return items
    }

    func doAction(_ action: Action, item: JiveItem? = nil) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: action.cmd) }
    }

    // MARK: - Alarms

    func fetchAlarms(start: Int = 0) async throws -> [Alarm] {
        guard let player = activePlayer else { return [] }
        let data = try await rpc.request(playerId: player.id,
                                         cmd: ["alarms", "\(start)", "100", "filter:all"])
        guard let loop = data["alarms_loop"] as? [[String: Any]] else { return [] }
        return loop.map { Alarm(record: $0) }
    }

    func addAlarm(time: Int) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["alarm", "add", "time:\(time)"]) }
    }

    func deleteAlarm(id: String) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["alarm", "delete", "id:\(id)"]) }
    }

    func enableAlarm(id: String, enabled: Bool) {
        guard let player = activePlayer else { return }
        let val = enabled ? "1" : "0"
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["alarm", "update", "id:\(id)", "enabled:\(val)"]) }
    }

    // MARK: - Server Admin

    func rescanLibrary() {
        Task { try? await rpc.request(cmd: ["rescan"]) }
    }

    func stopServer() {
        Task { try? await rpc.request(cmd: ["stopserver"]) }
    }

    func restartServer() {
        Task { try? await rpc.request(cmd: ["restartserver"]) }
    }

    func playlistClear() {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "clear"]) }
    }

    func playlistRemove(at index: Int) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "delete", "\(index)"]) }
    }

    func playlistMove(from: Int, to: Int) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "move", "\(from)", "\(to)"]) }
    }

    func playlistIndex(_ index: Int) {
        guard let player = activePlayer else { return }
        Task { try? await sendPlayerCommand(player: player.id, cmd: ["playlist", "index", "\(index)"]) }
    }

    // MARK: - Appliance (REST API)

    func configureAppliance(url: URL) {
        applianceClient.configure(baseURL: url)
    }

    func applianceInfo() async throws -> [String: Any] {
        try await applianceClient.fetchSystemInfo()
    }

    func audioOutputs() async throws -> [[String: Any]] {
        try await applianceClient.fetchAudioOutputs()
    }

    func dspSettings() async throws -> [String: Any] {
        try await applianceClient.fetchDspSettings()
    }

    func updateInfo() async throws -> [String: Any] {
        try await applianceClient.fetchUpdateInfo()
    }

    func triggerUpdate() {
        Task { try? await applianceClient.triggerUpdate() }
    }

    // MARK: - Private Helpers

    private func sendPlayerCommand(player: String, cmd: [String]) async throws {
        _ = try await rpc.request(playerId: player, cmd: cmd)
    }

    private func loadInitialServerStatus() async {
        do {
            let data = try await rpc.request(cmd: ["serverstatus", "0", "255"])
            handleServerStatus(data)
        } catch {}
    }

    private func setupCometCallbacks() {
        comet.onConnectionChanged = { [weak self] connected in
            Task { @MainActor [weak self] in
                self?.isConnected = connected
                self?.isConnecting = false
            }
        }

        comet.onServerStatus = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.handleServerStatus(data)
            }
        }

        comet.onPlayerStatus = { [weak self] playerId, data in
            Task { @MainActor [weak self] in
                self?.handlePlayerStatus(playerId: playerId, data: data)
            }
        }
    }

    private func handleServerStatus(_ data: [String: Any]) {
        serverVersion = Util.string(data, "version") ?? serverVersion

        let playerLoop = (data["players_loop"] as? [[String: Any]]) ?? []
        let updated = playerLoop.map { Player(record: $0) }

        // Merge: preserve existing playerState
        for newP in updated {
            if let existing = players.first(where: { $0.id == newP.id }) {
                existing.name = newP.name
                existing.connected = newP.connected
            } else {
                players.append(newP)
            }
        }
        // Remove disconnected
        let ids = Set(updated.map { $0.id })
        players.removeAll { !ids.contains($0.id) }
        players.sort()

        if activePlayer == nil, let first = players.first {
            setActivePlayer(first)
        }
    }

    private func handlePlayerStatus(playerId: String, data: [String: Any]) {
        guard let player = players.first(where: { $0.id == playerId }) else { return }
        player.playerState.update(from: data)

        if player.id == activePlayer?.id {
            syncFromActivePlayer()
            if let trackData = data["playlist_loop"] as? [[String: Any]], let first = trackData.first {
                currentTrack = CurrentTrack(record: first)
            }
        }
    }

    private func syncFromActivePlayer() {
        guard let player = activePlayer else { return }
        playStatus = player.playerState.playStatus
        currentVolume = player.playerState.currentVolume
        shuffleStatus = player.playerState.shuffleStatus
        repeatStatus = player.playerState.repeatStatus
        currentTimeSecond = player.playerState.currentTimeSecond
        currentTrackDuration = player.playerState.currentTrackDuration
    }

    private func parseJiveItems(from data: [String: Any]) -> (items: [JiveItem], total: Int) {
        let keys = ["item_loop", "albums_loop", "titles_loop", "playlists_loop",
                    "genres_loop", "artists_loop", "contributors_loop"]
        for key in keys {
            if let loop = data[key] as? [[String: Any]] {
                let items = loop.map { JiveItem(record: $0) }
                let total = Util.int(data, "count") ?? items.count
                return (items, total)
            }
        }
        return ([], 0)
    }
}
