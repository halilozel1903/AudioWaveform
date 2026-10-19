/// Reduces a stream of samples into waveform buckets without keeping the samples.
///
/// Feed it chunk by chunk while reading a file; the result is the same as `WaveformMath.buckets` on the whole
/// signal. The total sample count must be known up front (an audio file's length). If more samples arrive than
/// announced, they count towards the last bucket; buckets that never receive a sample are 0.
public struct BucketAccumulator: Sendable {
    /// The number of buckets produced: the requested count, but never more than `totalSamples`.
    public let bucketCount: Int
    /// The number of samples the buckets are laid out for.
    public let totalSamples: Int
    /// The number of samples appended so far.
    public private(set) var processedSamples = 0

    private var sumOfSquares: [Double]
    private var peaks: [Float]
    private var counts: [Int]
    private var bucket = 0
    private var bucketEnd: Int

    public init(bucketCount: Int, totalSamples: Int) {
        let total = max(0, totalSamples)
        let count = WaveformMath.effectiveBucketCount(requested: bucketCount, sampleCount: total)
        self.bucketCount = count
        self.totalSamples = total
        sumOfSquares = Array(repeating: 0, count: count)
        peaks = Array(repeating: 0, count: count)
        counts = Array(repeating: 0, count: count)
        bucketEnd = count > 0 ? WaveformMath.bucketRange(0, bucketCount: count, sampleCount: total).upperBound : 0
    }

    /// Whether every announced sample has been appended.
    public var isComplete: Bool { processedSamples >= totalSamples }

    /// Adds one sample. Non-finite samples count as silence.
    public mutating func append(_ sample: Float) {
        guard bucketCount > 0 else { return }
        while processedSamples >= bucketEnd && bucket < bucketCount - 1 {
            bucket += 1
            bucketEnd = WaveformMath.bucketRange(bucket, bucketCount: bucketCount, sampleCount: totalSamples).upperBound
        }
        let magnitude = sample.isFinite ? abs(sample) : 0
        sumOfSquares[bucket] += Double(magnitude) * Double(magnitude)
        if magnitude > peaks[bucket] {
            peaks[bucket] = magnitude
        }
        counts[bucket] += 1
        processedSamples += 1
    }

    /// Adds samples in order.
    public mutating func append<S: Sequence>(contentsOf samples: S) where S.Element == Float {
        for sample in samples {
            append(sample)
        }
    }

    /// The bucket values so far: RMS or peak per bucket, 0 for buckets without samples.
    public func values(for mode: WaveformSampleMode) -> [Float] {
        (0..<bucketCount).map { index in
            guard counts[index] > 0 else { return 0 }
            switch mode {
            case .peak:
                return peaks[index]
            case .rms:
                return Float((sumOfSquares[index] / Double(counts[index])).squareRoot())
            }
        }
    }
}
