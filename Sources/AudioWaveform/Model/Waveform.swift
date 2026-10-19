import Foundation

/// A downsampled waveform of an audio file: one value in `0...1` per bucket, plus the file's timing.
public struct Waveform: Sendable, Hashable {
    /// Bucket values in `0...1`, in time order.
    public var samples: [Float]
    /// The length of the audio in seconds.
    public var duration: TimeInterval
    /// The sample rate of the source audio, in Hz.
    public var sampleRate: Double
    /// Whether the buckets hold RMS or peak values.
    public var mode: WaveformSampleMode

    public init(samples: [Float], duration: TimeInterval, sampleRate: Double = 0, mode: WaveformSampleMode = .rms) {
        self.samples = samples
        self.duration = duration
        self.sampleRate = sampleRate
        self.mode = mode
    }

    /// A waveform without samples.
    public static let empty = Waveform(samples: [], duration: 0)

    public var isEmpty: Bool { samples.isEmpty }

    /// The samples fitted to `count` values (largest value per group when shrinking).
    public func resampled(to count: Int) -> [Float] {
        WaveformMath.resample(samples, to: count)
    }

    /// The time in seconds at a playback progress in `0...1`.
    public func time(atProgress progress: Double) -> TimeInterval {
        duration * min(max(progress, 0), 1)
    }

    /// The playback progress in `0...1` at a time in seconds.
    public func progress(atTime time: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1)
    }
}
