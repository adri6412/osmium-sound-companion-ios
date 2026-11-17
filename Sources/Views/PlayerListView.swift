import SwiftUI

struct PlayerListView: View {
    @Environment(LyrionService.self) private var service

    var body: some View {
        NavigationStack {
            List(service.players) { player in
                PlayerRow(player: player)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Players")
            .overlay {
                if service.players.isEmpty {
                    ContentUnavailableView(
                        "No Players",
                        systemImage: "speaker.slash",
                        description: Text("No players found on the server.")
                    )
                }
            }
        }
    }
}

struct PlayerRow: View {
    @Environment(LyrionService.self) private var service
    @ObservedObject var player: Player

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(player.playerState.poweredOn ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .bold(player.id == service.activePlayer?.id)
                HStack(spacing: 4) {
                    Text(player.model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if player.isSynced {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if player.id == service.activePlayer?.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }

            // Volume
            HStack(spacing: 4) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(player.playerState.currentVolume)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, alignment: .trailing)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            service.setActivePlayer(player)
        }
        .swipeActions(edge: .leading) {
            Button {
                service.togglePower(player: player)
            } label: {
                Label(player.playerState.poweredOn ? "Off" : "On",
                      systemImage: player.playerState.poweredOn ? "power.dotted" : "power")
            }
            .tint(player.playerState.poweredOn ? .orange : .green)
        }
        .swipeActions(edge: .trailing) {
            NavigationLink {
                PlayerDetailView(player: player)
            } label: {
                Label("Detail", systemImage: "info.circle")
            }
            .tint(.blue)
        }
    }
}

struct PlayerDetailView: View {
    @Environment(LyrionService.self) private var service
    @ObservedObject var player: Player

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Power", value: player.playerState.poweredOn ? "On" : "Off")
                LabeledContent("Volume") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(player.playerState.currentVolume) },
                            set: { service.setVolume(Int($0), player: player) }
                        ), in: 0...100, step: 1)
                        Text("\(player.playerState.currentVolume)")
                            .frame(width: 36)
                    }
                }
                LabeledContent("Status", value: player.playerState.playStatus.rawValue.capitalized)
                LabeledContent("IP", value: player.ip)
                LabeledContent("Model", value: player.model)
            }

            Section("Sync") {
                if let master = player.playerState.syncMaster {
                    LabeledContent("Synced to", value: master)
                    Button("Leave sync group") {
                        service.unsyncPlayer(player)
                    }
                    .foregroundStyle(.red)
                } else if !player.playerState.syncSlaves.isEmpty {
                    LabeledContent("Sync master", value: "Yes (\(player.playerState.syncSlaves.count) slaves)")
                } else {
                    Text("Not synced")
                        .foregroundStyle(.secondary)
                    // Could add "sync to…" picker here
                }
            }

            Section("Actions") {
                Button { service.togglePower(player: player) } label: {
                    Label(player.playerState.poweredOn ? "Turn Off" : "Turn On",
                          systemImage: "power")
                }
            }
        }
        .navigationTitle(player.name)
    }
}
