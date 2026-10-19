import Testing
@testable import AudioWaveform

@Suite("Normalisation and resampling")
struct NormalizationTests {
    @Test func normalizeScalesTheLoudestValueToOne() {
        #expect(isClose(WaveformMath.normalize([0.25, 0.5, -0.1]), [0.5, 1, -0.2]))
    }

    @Test func normalizeToACustomTarget() {
        #expect(isClose(WaveformMath.normalize([0.2, 0.4], to: 0.8), [0.4, 0.8]))
    }

    @Test func normalizeKeepsSilenceSilent() {
        #expect(WaveformMath.normalize([0, 0, 0]) == [0, 0, 0])
        #expect(WaveformMath.normalize([]).isEmpty)
    }

    @Test func clampedKeepsValuesInRange() {
        #expect(WaveformMath.clamped([-0.5, 0.5, 1.5, .nan]) == [0, 0.5, 1, 0])
    }

    @Test func downsamplingKeepsTheLargestValueOfEachGroup() {
        #expect(WaveformMath.resample([0.1, 0.9, 0.2, 0.4], to: 2) == [0.9, 0.4])
        #expect(WaveformMath.resample([0.1, 0.9, 0.2, 0.4, 0.3, 0.6], to: 3) == [0.9, 0.4, 0.6])
    }

    @Test func upsamplingInterpolates() {
        #expect(isClose(WaveformMath.resample([0, 1], to: 3), [0, 0.5, 1]))
        #expect(isClose(WaveformMath.resample([0, 1, 0], to: 5), [0, 0.5, 1, 0.5, 0]))
    }

    @Test func resampleEdgeCases() {
        #expect(WaveformMath.resample([0.3, 0.6], to: 2) == [0.3, 0.6])
        #expect(WaveformMath.resample([0.3], to: 3) == [0.3, 0.3, 0.3])
        #expect(WaveformMath.resample([0.3, 0.6], to: 0).isEmpty)
        #expect(WaveformMath.resample([], to: 4).isEmpty)
    }

    @Test func rollingHistoryDropsTheOldestValues() {
        var history: [Float] = []
        for value in [0.1, 0.2, 0.3, 0.4] as [Float] {
            history = WaveformMath.appending(value, to: history, capacity: 3)
        }
        #expect(history == [0.2, 0.3, 0.4])
        #expect(WaveformMath.appending(0.5, to: [0.1], capacity: 0).isEmpty)
    }

    @Test func waveformTimeAndProgress() {
        let waveform = Waveform(samples: [0.5, 1], duration: 20)
        #expect(waveform.time(atProgress: 0.25) == 5)
        #expect(waveform.time(atProgress: 2) == 20)
        #expect(waveform.progress(atTime: 15) == 0.75)
        #expect(Waveform.empty.progress(atTime: 3) == 0)
        #expect(waveform.resampled(to: 1) == [1])
    }
}
