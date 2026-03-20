import Foundation

/// Short, user-facing strings for product shell and retry flows (Phase 6).
public enum VDTOnboardingCopy {
    public static let holdSteadyTitle = "Hold steady"
    public static let holdSteadyBody =
        "Point the camera at the sender screen. Keep both devices still; bright, even lighting helps the grid decode."

    public static let retryAfterRejectTitle = "Chunk didn’t fit"
    public static let retryAfterRejectBody =
        "Tap “Reset assembly” and wait for the sender to show the descriptor again, or align the camera so the full grid is visible."

    public static let receiverGridTip =
        "Tip: default sampling matches the sender’s margin/gap grid. Use C++ full-bleed only for homography experiments."
}
