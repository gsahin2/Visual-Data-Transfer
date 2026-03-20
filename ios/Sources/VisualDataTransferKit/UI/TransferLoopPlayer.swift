import Combine
import Foundation
import SwiftUI

/// Drives repeated playback of one transfer loop cycle (`VDTFramedSession.frames`).
@MainActor
public final class TransferLoopPlayer: ObservableObject {
    @Published public private(set) var frameIndex: Int = 0
    @Published public var isPlaying: Bool = false {
        didSet { isPlaying ? startTimer() : stopTimer() }
    }

    /// Display frames per second (one wire frame per tick).
    @Published public var framesPerSecond: Double = 12 {
        didSet {
            if isPlaying {
                stopTimer()
                startTimer()
            }
        }
    }

    @Published public private(set) var frames: [Data] = []

    private var cancellable: AnyCancellable?

    public init() {}

    public func load(frames: [Data]) {
        self.frames = frames
        frameIndex = 0
        if isPlaying {
            stopTimer()
            startTimer()
        }
    }

    public var currentWire: Data? {
        guard !frames.isEmpty, frameIndex >= 0, frameIndex < frames.count else { return nil }
        return frames[frameIndex]
    }

    public var parsedCurrent: VDTWireFrame? {
        guard let w = currentWire else { return nil }
        return VDTWireFrameParser.parse(w)
    }

    private func startTimer() {
        guard !frames.isEmpty else { return }
        stopTimer()
        let interval = max(1.0 / 120.0, 1.0 / framesPerSecond)
        cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.frames.isEmpty else { return }
                self.frameIndex = (self.frameIndex + 1) % self.frames.count
            }
    }

    private func stopTimer() {
        cancellable?.cancel()
        cancellable = nil
    }

    public func stepForward() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
    }

    public func reset() {
        frameIndex = 0
    }
}
