import AVFAudio
import Foundation

/// The level of one buffer of live audio.
public struct AudioLevel: Sendable, Hashable {
    /// The root mean square of the buffer, linear (1 is full scale).
    public var rms: Float
    /// The largest absolute sample of the buffer, linear.
    public var peak: Float
    /// How much audio the buffer held, in seconds.
    public var duration: TimeInterval

    public init(rms: Float, peak: Float, duration: TimeInterval) {
        self.rms = rms
        self.peak = peak
        self.duration = duration
    }

    /// Measures samples of one channel.
    public init(samples: [Float], sampleRate: Double) {
        self.init(
            rms: WaveformMath.rms(samples),
            peak: WaveformMath.peak(samples),
            duration: sampleRate > 0 ? Double(samples.count) / sampleRate : 0
        )
    }

    /// Measures a buffer from an engine tap or a file, across all its channels. Buffers that are not 32-bit float
    /// (rare: taps and `AVAudioFile` deliver float) measure as silence.
    public init(measuring buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        let duration = sampleRate > 0 ? Double(frames) / sampleRate : 0
        guard frames > 0, channelCount > 0, let channels = buffer.floatChannelData else {
            self.init(rms: 0, peak: 0, duration: duration)
            return
        }
        // Deinterleaved buffers have one pointer per channel; interleaved ones keep every channel behind the first.
        let interleaved = buffer.format.isInterleaved
        let step = interleaved ? channelCount : 1
        var sum: Double = 0
        var peak: Float = 0
        for channel in 0..<channelCount {
            let samples = interleaved ? channels[0] + channel : channels[channel]
            for frame in 0..<frames {
                let sample = samples[frame * step]
                guard sample.isFinite else { continue }
                sum += Double(sample) * Double(sample)
                peak = max(peak, abs(sample))
            }
        }
        let rms = Float((sum / Double(frames * channelCount)).squareRoot())
        self.init(rms: rms, peak: peak, duration: duration)
    }

    /// The RMS level in decibels full scale.
    public var rmsDecibels: Float { WaveformMath.decibels(fromAmplitude: rms) }

    /// The peak level in decibels full scale.
    public var peakDecibels: Float { WaveformMath.decibels(fromAmplitude: peak) }

    /// The RMS level mapped onto `0...1` for a meter, with `floor` decibels and below as 0.
    public func normalized(floor: Float = -50) -> Float {
        WaveformMath.normalizedLevel(decibels: rmsDecibels, floor: floor)
    }
}
