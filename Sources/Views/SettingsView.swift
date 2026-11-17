import SwiftUI

struct SettingsView: View {
    @Environment(LyrionService.self) private var service
    @AppStorage("serverHost") private var host = ""
    @AppStorage("serverPort") private var port = 9000

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    LabeledContent("Host", value: host.isEmpty ? "—" : host)
                    LabeledContent("Port", value: "\(port)")
                    LabeledContent("Version", value: service.serverVersion.isEmpty ? "—" : service.serverVersion)
                    LabeledContent("Status", value: service.isConnected ? "Connected" : "Disconnected")

                    Button(role: .destructive) {
                        service.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "wifi.slash")
                    }
                }

                Section("Library") {
                    Button {
                        service.rescanLibrary()
                    } label: {
                        Label("Rescan Library", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("Players") {
                    ForEach(service.players) { player in
                        NavigationLink {
                            PlayerDetailView(player: player)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(player.playerState.poweredOn ? .green : .gray.opacity(0.4))
                                    .frame(width: 8, height: 8)
                                Text(player.name)
                            }
                        }
                    }
                }

                Section("Appliance") {
                    NavigationLink("System Info") {
                        SystemInfoView()
                    }
                    NavigationLink("Audio Output") {
                        AudioOutputView()
                    }
                    NavigationLink("DSP Settings") {
                        DspSettingsView()
                    }
                    NavigationLink("Updates") {
                        UpdatesView()
                    }
                }

                Section("Alarms") {
                    NavigationLink("Manage Alarms") {
                        AlarmsView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
