import Foundation
import Testing
@testable import AudioWaveform

@Suite("Bucketing")
struct BucketingTests {
    @Test func rangesCoverEverySampleOnce() {
        let ranges = (0..<3).map { WaveformMath.bucketRange($0, bucketCount: 3, sampleCount: 10) }
        #expect(ranges == [0..<3, 3..<6, 6..<10])
    }

    @Test func rangeSizesDifferByAtMostOne() {
        let sizes = (0..<4).map { WaveformMath.bucketRange($0, bucketCount: 4, sampleCount: 10).count }
        #expect(sizes == [2, 3, 2, 3])
        #expect(sizes.reduce(0, +) == 10)
    }

    @Test func rangeOutsideTheBucketsIsEmpty() {
        #expect(WaveformMath.bucketRange(5, bucketCount: 3, sampleCount: 10).isEmpty)
        #expect(WaveformMath.bucketRange(-1, bucketCount: 3, sampleCount: 10).isEmpty)
        #expect(WaveformMath.bucketRange(0, bucketCount: 0, sampleCount: 10).isEmpty)
    }

    @Test func peakBuckets() {
        let samples: [Float] = [0.1, -0.9, 0.3, 0.2, -0.4, 0.8]
        #expect(isClose(WaveformMath.buckets(samples, count: 3, mode: .peak), [0.9, 0.3, 0.8]))
    }

    @Test func rmsBuckets() {
        let samples: [Float] = [0.1, -0.9, 0.3, 0.2, -0.4, 0.8]
        let expected: [Float] = [Float(0.41).squareRoot(), Float(0.065).squareRoot(), Float(0.4).squareRoot()]
        #expect(isClose(WaveformMath.buckets(samples, count: 3, mode: .rms), expected))
    }

    @Test func rmsOfASquareWaveIsItsAmplitude() {
        let samples = squareWave(amplitude: 0.5, count: 100) + squareWave(amplitude: 0.25, count: 100)
        #expect(isClose(WaveformMath.buckets(samples, count: 2, mode: .rms), [0.5, 0.25]))
    }

    @Test func fewerSamplesThanBucketsGiveOneBucketPerSample() {
        #expect(isClose(WaveformMath.buckets([0.5, -1], count: 8, mode: .peak), [0.5, 1]))
    }

    @Test func emptyInputOrNoBuckets() {
        #expect(WaveformMath.buckets([], count: 4).isEmpty)
        #expect(WaveformMath.buckets([0.5, 0.2], count: 0).isEmpty)
        #expect(WaveformMath.buckets([0.5, 0.2], count: -3).isEmpty)
    }

    @Test func chunkedAccumulationMatchesOneShot() {
        let samples = (0..<1000).map { index in Float(sin(Double(index) * 0.05) * Double(index) / 1000) }
        var accumulator = BucketAccumulator(bucketCount: 37, totalSamples: samples.count)
        var start = 0
        while start < samples.count {
            let end = min(start + 7, samples.count)
            accumulator.append(contentsOf: samples[start..<end])
            start = end
        }
        let isComplete = accumulator.isComplete
        #expect(isComplete)
        #expect(isClose(accumulator.values(for: .rms), WaveformMath.buckets(samples, count: 37, mode: .rms)))
        #expect(isClose(accumulator.values(for: .peak), WaveformMath.buckets(samples, count: 37, mode: .peak)))
    }

    @Test func extraSamplesCountTowardsTheLastBucket() {
        var accumulator = BucketAccumulator(bucketCount: 2, totalSamples: 4)
        accumulator.append(contentsOf: [0, 0, 0, 0, 1, 1] as [Float])
        #expect(isClose(accumulator.values(for: .peak), [0, 1]))
        #expect(accumulator.processedSamples == 6)
    }

    @Test func missingSamplesLeaveBucketsAtZero() {
        var accumulator = BucketAccumulator(bucketCount: 4, totalSamples: 8)
        accumulator.append(contentsOf: [0.5, 0.5, 0.25] as [Float])
        #expect(isClose(accumulator.values(for: .peak), [0.5, 0.25, 0, 0]))
        let isComplete = accumulator.isComplete
        #expect(!isComplete)
    }

    @Test func nonFiniteSamplesCountAsSilence() {
        let samples: [Float] = [.nan, 0.5, .infinity, -0.5]
        #expect(isClose(WaveformMath.buckets(samples, count: 2, mode: .peak), [0.5, 0.5]))
        #expect(isClose(WaveformMath.rms([Float.nan, 1]), (0.5 as Float).squareRoot()))
    }

    @Test func rmsAndPeakHelpers() {
        #expect(WaveformMath.rms([Float]()) == 0)
        #expect(WaveformMath.peak([Float]()) == 0)
        #expect(isClose(WaveformMath.rms([3, -4] as [Float]), (12.5 as Float).squareRoot()))
        #expect(WaveformMath.peak([0.2, -0.7, 0.4] as [Float]) == 0.7)
    }
}
