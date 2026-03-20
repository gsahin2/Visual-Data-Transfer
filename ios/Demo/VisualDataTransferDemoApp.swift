import SwiftUI
import VisualDataTransferKit

@main
struct VisualDataTransferDemoApp: App {
    @AppStorage(VDTProductFlags.integratedExperienceUserDefaultsKey) private var integratedProduct = false

    var body: some Scene {
        WindowGroup {
            Group {
                if integratedProduct {
                    ProductTransferExperience()
                } else {
                    classicTabView
                }
            }
        }
    }

    private var classicTabView: some View {
        TabView {
            NavigationStack {
                SenderView()
                    .navigationTitle("Sender")
            }
            .tabItem { Label("Sender", systemImage: "square.grid.3x3") }

            NavigationStack {
                ReceiverScreen()
                    .navigationTitle("Receiver")
            }
            .tabItem { Label("Receiver", systemImage: "camera") }

            NavigationStack {
                DemoSettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct DemoSettingsView: View {
    @AppStorage(VDTProductFlags.integratedExperienceUserDefaultsKey) private var integrated = false
    @State private var entryCount = 0

    var body: some View {
        Form {
            Section("Product shell") {
                Toggle("Integrated product UI", isOn: $integrated)
                Text("Turn on for Send/Receive in one flow, onboarding, and session log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Session test log") {
                Text("Entries stored on device: \(entryCount)")
                Button("Refresh count") {
                    refresh()
                }
            }
            Section("Public API") {
                Text(
                    "Encode without UI: VisualDataTransfer.encodeLoopCycle(message:configuration:)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        entryCount = (try? VDTSessionTestLog.loadEntries().count) ?? 0
    }
}
