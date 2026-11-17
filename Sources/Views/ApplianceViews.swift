import SwiftUI

// MARK: - System Info

struct SystemInfoView: View {
    @Environment(LyrionService.self) private var service
    @State private var info: [String: Any] = [:]
    @State private var isLoading = false

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
            } else {
                ForEach(Array(info.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                    LabeledContent(key, value: "\(value)")
                }
            }
        }
        .navigationTitle("System Info")
        .task {
            isLoading = true
            info = (try? await service.applianceInfo()) ?? [:]
            isLoading = false
        }
    }
}

// MARK: - Audio Output

struct AudioOutputView: View {
    @Environment(LyrionService.self) private var service
    @State private var outputs: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        List(outputs, id: \.description) { output in
            Text(output["name"] as? String ?? "Unknown")
        }
        .navigationTitle("Audio Output")
        .task {
            isLoading = true
            outputs = (try? await service.audioOutputs()) ?? []
            isLoading = false
        }
    }
}

// MARK: - DSP Settings

struct DspSettingsView: View {
    @Environment(LyrionService.self) private var service
    @State private var settings: [String: Any] = [:]

    var body: some View {
        Form {
            ForEach(Array(settings.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                LabeledContent(key, value: "\(value)")
            }
        }
        .navigationTitle("DSP Settings")
        .task {
            settings = (try? await service.dspSettings()) ?? [:]
        }
    }
}

// MARK: - Updates

struct UpdatesView: View {
    @Environment(LyrionService.self) private var service
    @State private var updateInfo: [String: Any] = [:]
    @State private var showConfirm = false

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Available", value: updateInfo["available"] as? String ?? "—")
                LabeledContent("Current", value: updateInfo["current"] as? String ?? "—")
            }
            Section {
                Button("Check for Updates") {
                    Task { updateInfo = (try? await service.updateInfo()) ?? [:] }
                }
                if updateInfo["available"] != nil {
                    Button("Apply Update", role: .destructive) {
                        showConfirm = true
                    }
                }
            }
        }
        .navigationTitle("Updates")
        .confirmationDialog("Apply Update?", isPresented: $showConfirm) {
            Button("Apply", role: .destructive) { service.triggerUpdate() }
        }
        .task {
            updateInfo = (try? await service.updateInfo()) ?? [:]
        }
    }
}
