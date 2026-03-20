import Combine
import Foundation
import SwiftUI

#if os(iOS)
import QuartzCore

/// Throttles `CADisplayLink` ticks to approximately `framesPerSecond` advances.
private final class IOSDisplayLinkAdapter: NSObject {
    var onStep: (() -> Void)?
    var framesPerSecond: Double = 12 {
        didSet { leftover = 0 }
    }

    private var link: CADisplayLink?
    private var leftover: CFTimeInterval = 0

    func start() {
        stop()
        leftover = 0
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
        leftover = 0
    }

    @objc private func tick(_ sender: CADisplayLink) {
        let step = 1.0 / max(1.0, framesPerSecond)
        leftover += sender.duration
        while leftover >= step {
            leftover -= step
            onStep?()
        }
    }
}
#endif

/// Drives repeated playback of one transfer loop cycle (`VDTFramedSession.frames`).
@MainActor
public final class TransferLoopPlayer: ObservableObject {
    @Published public private(set) var frameIndex: Int = 0
    /// Number of times playback wrapped from the last frame back to index `0` (full loop cycles completed).
    @Published public private(set) var completedLoopCount: Int = 0
    /// When set, `isPlaying` becomes `false` after this many **completed** loops (`nil` = run until user pauses).
    @Published public var maxCompletedLoops: Int? = nil

    @Published public var isPlaying: Bool = false {
        didSet { isPlaying ? startTimer() : stopTimer() }
    }

    /// Target steps per second (one wire frame per step).
    @Published public var framesPerSecond: Double = 12 {
        didSet {
            #if os(iOS)
            iosLink?.framesPerSecond = framesPerSecond
            #endif
            if isPlaying {
                stopTimer()
                startTimer()
            }
        }
    }

    @Published public private(set) var frames: [Data] = []

    private var cancellable: AnyCancellable?
    #if os(iOS)
    private var iosLink: IOSDisplayLinkAdapter?
    #endif

    public init() {}

    public func load(frames: [Data]) {
        self.frames = frames
        frameIndex = 0
        completedLoopCount = 0
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
        #if os(iOS)
        let adapter = IOSDisplayLinkAdapter()
        adapter.framesPerSecond = framesPerSecond
        adapter.onStep = { [weak self] in
            Task { @MainActor in
                guard let self, !self.frames.isEmpty else { return }
                self.advanceFrame()
            }
        }
        adapter.start()
        iosLink = adapter
        #else
        let interval = max(1.0 / 120.0, 1.0 / framesPerSecond)
        cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.frames.isEmpty else { return }
                self.advanceFrame()
            }
        #endif
    }

    private func stopTimer() {
        cancellable?.cancel()
        cancellable = nil
        #if os(iOS)
        iosLink?.stop()
        iosLink = nil
        #endif
    }

    public func stepForward() {
        guard !frames.isEmpty else { return }
        advanceFrame()
    }

    public func reset() {
        frameIndex = 0
    }

    private func advanceFrame() {
        guard !frames.isEmpty else { return }
        let n = frames.count
        let wasAtEnd = frameIndex == n - 1
        frameIndex = (frameIndex + 1) % n
        if wasAtEnd, frameIndex == 0 {
            completedLoopCount += 1
            if let cap = maxCompletedLoops, cap > 0, completedLoopCount >= cap {
                isPlaying = false
            }
        }
    }
}
