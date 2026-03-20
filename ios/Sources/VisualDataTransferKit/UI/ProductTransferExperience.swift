#if os(iOS)
import SwiftUI

/// Integrated **Send / Receive** shell with first-run tips and a field-test logger (Phase 6).
public struct ProductTransferExperience: View {
    @State private var role: Role = .send
    @State private var showOnboarding = !VDTProductFlags.onboardingTipsDismissed
    @State private var showLogSheet = false
    @State private var exportWrapper: LogExportItem?
    @StateObject private var receiverController = ReceiverController()

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showOnboarding {
                    onboardingBanner
                }
                Picker("Role", selection: $role) {
                    Text("Send").tag(Role.send)
                    Text("Receive").tag(Role.receive)
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch role {
                    case .send:
                        SenderView(showTitle: false)
                    case .receive:
                        ReceiverView(controller: receiverController, showAdvancedToggles: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Visual Data Transfer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Log field session…") {
                            showLogSheet = true
                        }
                        Button("Export log JSON…") {
                            if let u = try? VDTSessionTestLog.exportTemporaryJSON() {
                                exportWrapper = LogExportItem(url: u)
                            }
                        }
                    } label: {
                        Label("Session log", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showLogSheet) {
                SessionTestLogSheet()
            }
            .sheet(item: $exportWrapper) { item in
                NavigationStack {
                    VStack(spacing: 20) {
                        ShareLink("Share JSON", item: item.url)
                        Button("Close") {
                            exportWrapper = nil
                        }
                    }
                    .padding()
                    .navigationTitle("Export")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private struct LogExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var onboardingBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VDTOnboardingCopy.holdSteadyTitle).font(.headline)
            Text(VDTOnboardingCopy.holdSteadyBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Got it") {
                VDTProductFlags.onboardingTipsDismissed = true
                showOnboarding = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private enum Role {
        case send
        case receive
    }
}

private struct SessionTestLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var distanceText = ""
    @State private var lighting = ""
    @State private var outcome = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Field test (device matrix)") {
                    TextField("Distance (cm), optional", text: $distanceText)
                        .keyboardType(.numberPad)
                    TextField("Lighting (e.g. office / sunlight)", text: $lighting)
                    TextField("Outcome (e.g. OK in 8s, CRC fail)", text: $outcome)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
            .navigationTitle("Log session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let dist = Int(distanceText.trimmingCharacters(in: .whitespaces))
        let entry = VDTSessionTestEntry(
            deviceModel: VDTSessionTestLog.currentDeviceSummary,
            systemVersion: VDTSessionTestLog.currentSystemVersion,
            distanceCm: dist,
            lightingNote: lighting,
            outcomeNote: outcome.isEmpty ? "(no notes)" : outcome
        )
        do {
            try VDTSessionTestLog.append(entry)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#else
import SwiftUI

public struct ProductTransferExperience: View {
    public init() {}
    public var body: some View {
        Text("Product shell requires iOS").padding()
    }
}
#endif
