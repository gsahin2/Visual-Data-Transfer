import SwiftUI
import VisualDataTransferKit

@main
struct VisualDataTransferDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    SenderScreen()
                        .navigationTitle("Sender")
                }
                .tabItem { Label("Sender", systemImage: "square.grid.3x3") }

                NavigationStack {
                    ReceiverScreen()
                        .navigationTitle("Receiver")
                }
                .tabItem { Label("Receiver", systemImage: "camera") }
            }
        }
    }
}
