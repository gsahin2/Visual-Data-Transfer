#if os(iOS)
import SwiftUI

/// Developer-friendly wrapper that owns a default ``ReceiverController``.
public struct ReceiverScreen: View {
    @StateObject private var controller = ReceiverController()

    public init() {}

    public var body: some View {
        ReceiverView(controller: controller)
    }
}
#else
import SwiftUI

public struct ReceiverScreen: View {
    public init() {}
    public var body: some View {
        Text("Receiver requires iOS")
            .padding()
    }
}
#endif
