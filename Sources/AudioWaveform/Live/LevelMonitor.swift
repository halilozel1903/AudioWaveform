import Foundation
import Observation

/// Turns a stream of live levels into state for a recording meter: a smoothed level, a peak hold, a rolling
/// history for a scrolling waveform, the level in decibels and the elapsed time.
///
/// ```swift
/// let monitor = LevelMonitor()
/// #if targetEnvironment(simulator)
/// monitor.start(FileLevelSource(url: demoURL))   // the simulator has no useful microphone
/// #else
/// monitor.start(MicrophoneLevelSource())
/// #endif
/// ```
@MainActor
@Observable
public final class LevelMonitor {
    /// Recent levels in `0...1`, oldest first, at most `capacity` of them.
    public private(set) var history: [Float] = []
    /// The current level in `0...1`, smoothed with a fast attack and a slower release.
    public private(set) var level: Float = 0
    /// The highest recent level in `0...1`, falling back slowly.
    public private(set) var peakHold: Float = 0
    /// The last RMS level in decibels full scale.
    public private(set) var decibels: Float = WaveformMath.silenceDecibels
    /// Seconds of audio measured since `start`.
    public private(set) var elapsed: TimeInterval = 0
    /// Whether a source is running.
    public private(set) var isRunning = false
    /// The last error from the source, such as a denied microphone permission.
    public private(set) var errorMessage: String?

    /// How many levels `history` keeps.
    public var capacity: Int
    /// The decibel level shown as empty; quieter input reads as 0.
    public var floorDecibels: Float
    /// How much of the gap to the peak hold closes per level when the level falls (0 holds forever).
    public var peakRelease: Float = 0.04

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var run = 0

    public init(capacity: Int = 120, floorDecibels: Float = -50) {
        self.capacity = capacity
        self.floorDecibels = floorDecibels
    }

    /// Clears the state and starts listening to `source`. A running source is stopped first.
    public func start(_ source: some AudioLevelSource) {
        stop()
        reset()
        run += 1
        let current = run
        isRunning = true
        let stream = source.levels()
        task = Task { [weak self] in
            do {
                for try await level in stream {
                    guard let self, self.run == current else { return }
                    self.receive(level)
                }
                self?.finish(run: current, error: nil)
            } catch {
                self?.finish(run: current, error: error)
            }
        }
    }

    /// Stops the source. The history stays on screen until the next `start` or `reset`.
    public func stop() {
        run += 1
        task?.cancel()
        task = nil
        isRunning = false
    }

    /// Clears the history, the levels, the elapsed time and the error.
    public func reset() {
        history = []
        level = 0
        peakHold = 0
        decibels = WaveformMath.silenceDecibels
        elapsed = 0
        errorMessage = nil
    }

    /// Applies one level, as the stream does. Public so you can drive the monitor from your own tap.
    public func receive(_ newLevel: AudioLevel) {
        let target = newLevel.normalized(floor: floorDecibels)
        level = WaveformMath.smoothed(level, toward: target)
        peakHold = target >= peakHold ? target : WaveformMath.smoothed(peakHold, toward: target, attack: 1, release: peakRelease)
        decibels = newLevel.rmsDecibels
        elapsed += newLevel.duration
        history = WaveformMath.appending(target, to: history, capacity: capacity)
    }

    private func finish(run finished: Int, error: (any Error)?) {
        guard finished == run else { return }
        task = nil
        isRunning = false
        if let error, !(error is CancellationError) {
            errorMessage = error.localizedDescription
        }
    }
}
