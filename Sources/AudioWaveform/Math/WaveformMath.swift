import Foundation

/// How a bucket of audio samples becomes one waveform value.
public enum WaveformSampleMode: String, Sendable, Hashable, CaseIterable {
    /// The root mean square of the bucket: close to perceived loudness, smoother shapes.
    case rms
    /// The largest absolute sample in the bucket: shows every transient, spikier shapes.
    case peak
}

/// The pure math behind waveforms and level meters: bucketing, normalisation, resampling, decibels and meter
/// ballistics. Everything here is deterministic and free of audio APIs, so it is easy to test and reuse.
public enum WaveformMath {
    /// The decibel value used for silence (an amplitude of zero).
    public static let silenceDecibels: Float = -160

    // MARK: Bucketing

    /// The samples that fall into bucket `index` when `sampleCount` samples are split into `bucketCount` buckets.
    ///
    /// Buckets are contiguous, never overlap, cover every sample and differ in size by at most one sample.
    /// Returns an empty range for an index outside `0..<bucketCount`.
    public static func bucketRange(_ index: Int, bucketCount: Int, sampleCount: Int) -> Range<Int> {
        guard bucketCount > 0, sampleCount > 0, index >= 0, index < bucketCount else { return 0..<0 }
        let lower = Int(Int64(index) * Int64(sampleCount) / Int64(bucketCount))
        let upper = Int(Int64(index + 1) * Int64(sampleCount) / Int64(bucketCount))
        return lower..<upper
    }

    /// The number of buckets actually produced: never more than there are samples, so no bucket is empty.
    public static func effectiveBucketCount(requested: Int, sampleCount: Int) -> Int {
        max(0, min(requested, sampleCount))
    }

    /// Splits `samples` into `count` buckets and reduces each one to its RMS or peak value.
    ///
    /// Values are absolute (never negative). With fewer samples than buckets, there is one bucket per sample.
    public static func buckets(_ samples: [Float], count: Int, mode: WaveformSampleMode = .rms) -> [Float] {
        var accumulator = BucketAccumulator(bucketCount: count, totalSamples: samples.count)
        accumulator.append(contentsOf: samples)
        return accumulator.values(for: mode)
    }

    /// The root mean square of the samples, or 0 for none.
    public static func rms<C: Collection>(_ samples: C) -> Float where C.Element == Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Double = 0
        for sample in samples where sample.isFinite {
            sum += Double(sample) * Double(sample)
        }
        return Float((sum / Double(samples.count)).squareRoot())
    }

    /// The largest absolute sample, or 0 for none.
    public static func peak<C: Collection>(_ samples: C) -> Float where C.Element == Float {
        samples.reduce(0) { $1.isFinite ? max($0, abs($1)) : $0 }
    }

    // MARK: Normalisation and resampling

    /// Scales the values so the largest absolute value becomes `target`. All-zero input stays zero.
    public static func normalize(_ values: [Float], to target: Float = 1) -> [Float] {
        let top = peak(values)
        guard top > 0 else { return values.map { _ in 0 } }
        let scale = target / top
        return values.map { $0.isFinite ? $0 * scale : 0 }
    }

    /// Clamps every value into `0...1`; non-finite values become 0.
    public static func clamped(_ values: [Float]) -> [Float] {
        values.map { $0.isFinite ? min(max($0, 0), 1) : 0 }
    }

    /// Fits the values to `count` points: downsampling keeps the largest value of each group (so peaks never
    /// disappear when a waveform is drawn narrower), upsampling interpolates linearly.
    public static func resample(_ values: [Float], to count: Int) -> [Float] {
        guard count > 0, !values.isEmpty else { return [] }
        if values.count == count { return values }
        if values.count > count {
            return (0..<count).map { index in
                let range = bucketRange(index, bucketCount: count, sampleCount: values.count)
                return values[range].max() ?? 0
            }
        }
        if values.count == 1 || count == 1 {
            return Array(repeating: values[0], count: count)
        }
        let last = values.count - 1
        return (0..<count).map { index in
            let position = Double(index) * Double(last) / Double(count - 1)
            let lower = min(Int(position.rounded(.down)), last)
            let upper = min(lower + 1, last)
            let fraction = Float(position - Double(lower))
            return values[lower] + (values[upper] - values[lower]) * fraction
        }
    }

    // MARK: Decibels

    /// Converts a linear amplitude (1 is full scale) to decibels full scale: 20·log10(|amplitude|).
    /// Zero and non-finite amplitudes give `silenceDecibels`.
    public static func decibels(fromAmplitude amplitude: Float) -> Float {
        let magnitude = abs(amplitude)
        guard magnitude > 0, magnitude.isFinite else { return silenceDecibels }
        return max(silenceDecibels, 20 * log10(magnitude))
    }

    /// Converts decibels full scale back to a linear amplitude. `silenceDecibels` and below give 0.
    public static func amplitude(fromDecibels decibels: Float) -> Float {
        guard decibels > silenceDecibels, decibels.isFinite else { return 0 }
        return pow(10, decibels / 20)
    }

    /// Maps decibels onto `0...1` for a meter: `floor` (for example -50 dB) and below are 0, 0 dB and above are 1,
    /// linear in decibels in between.
    public static func normalizedLevel(decibels: Float, floor: Float = -50) -> Float {
        guard floor < 0 else { return decibels >= 0 ? 1 : 0 }
        if decibels <= floor { return 0 }
        if decibels >= 0 { return 1 }
        return (decibels - floor) / -floor
    }

    // MARK: Meters

    /// Moves a meter value towards `target`: quickly when it rises (`attack`), slowly when it falls (`release`).
    /// Both coefficients are the fraction of the distance covered per update, clamped into `0...1`.
    public static func smoothed(_ previous: Float, toward target: Float, attack: Float = 0.6, release: Float = 0.15) -> Float {
        let coefficient = min(max(target > previous ? attack : release, 0), 1)
        return previous + (target - previous) * coefficient
    }

    /// Appends a value to a rolling history and drops the oldest values beyond `capacity`.
    public static func appending(_ value: Float, to history: [Float], capacity: Int) -> [Float] {
        guard capacity > 0 else { return [] }
        var result = history
        result.append(value)
        if result.count > capacity {
            result.removeFirst(result.count - capacity)
        }
        return result
    }
}
