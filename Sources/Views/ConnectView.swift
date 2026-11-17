import SwiftUI

struct ConnectView: View {
    @Environment(LyrionService.self) private var service
    @AppStorage("serverHost") private var host = ""
    @AppStorage("serverPort") private var port = 9000
    @AppStorage("serverUsername") private var username = ""
    @AppStorage("serverPassword") private var password = ""

    @State private var portString = "9000"

    var body: some View {
        NavigationStack {
            Form {
                Section("Lyrion Music Server") {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                        TextField("Server address (e.g. 192.168.1.100)", text: $host)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    HStack {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        TextField("Port", text: $portString)
                            .keyboardType(.numberPad)
                            .onChange(of: portString) {
                                port = Int(portString) ?? 9000
                            }
                    }
                }

                Section("Authentication (optional)") {
                    HStack {
                        Image(systemName: "person")
                            .foregroundStyle(.secondary)
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    HStack {
                        Image(systemName: "lock")
                            .foregroundStyle(.secondary)
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                }

                Section {
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            if service.isConnecting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Connecting…")
                            } else {
                                Image(systemName: "wifi")
                                Text("Connect")
                            }
                            Spacer()
                        }
                    }
                    .disabled(host.isEmpty || service.isConnecting)
                }

                if let error = service.connectionError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Osmium Sound")
            .onAppear {
                portString = "\(port)"
                if !host.isEmpty && !service.isConnecting {
                    connect()
                }
            }
        }
    }

    private func connect() {
        service.connect(host: host, port: port, username: username, password: password)
    }
}
