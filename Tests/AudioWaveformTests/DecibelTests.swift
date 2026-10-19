import Testing
@testable import AudioWaveform

@Suite("Decibels and meters")
struct DecibelTests {
    @Test func fullScaleIsZeroDecibels() {
        #expect(WaveformMath.decibels(fromAmplitude: 1) == 0)
    }

    @Test func halvingTheAmplitudeIsAboutMinusSixDecibels() {
        #expect(isClose(WaveformMath.decibels(fromAmplitude: 0.5), -6.0206))
        #expect(isClose(WaveformMath.decibels(fromAmplitude: -0.1), -20))
    }

    @Test func silenceHasAFloor() {
        #expect(WaveformMath.decibels(fromAmplitude: 0) == WaveformMath.silenceDecibels)
        #expect(WaveformMath.decibels(fromAmplitude: .nan) == WaveformMath.silenceDecibels)
        #expect(WaveformMath.decibels(fromAmplitude: 1e-20) == WaveformMath.silenceDecibels)
        #expect(WaveformMath.amplitude(fromDecibels: WaveformMath.silenceDecibels) == 0)
    }

    @Test(arguments: [1.0, 0.5, 0.1, 0.0125] as [Float])
    func amplitudeRoundTrips(amplitude: Float) {
        let decibels = WaveformMath.decibels(fromAmplitude: amplitude)
        #expect(isClose(WaveformMath.amplitude(fromDecibels: decibels), amplitude, tolerance: 1e-5))
    }

    @Test func meterLevelIsLinearInDecibels() {
        #expect(WaveformMath.normalizedLevel(decibels: -25, floor: -50) == 0.5)
        #expect(WaveformMath.normalizedLevel(decibels: -60, floor: -50) == 0)
        #expect(WaveformMath.normalizedLevel(decibels: 3, floor: -50) == 1)
        #expect(WaveformMath.normalizedLevel(decibels: -10, floor: 0) == 0)
    }

    @Test func meterRisesQuicklyAndFallsSlowly() {
        let rise = WaveformMath.smoothed(0, toward: 1, attack: 0.5, release: 0.1)
        let fall = WaveformMath.smoothed(1, toward: 0, attack: 0.5, release: 0.1)
        #expect(isClose(rise, 0.5))
        #expect(isClose(fall, 0.9))
        #expect(WaveformMath.smoothed(0.4, toward: 0.4) == 0.4)
    }

    @Test func audioLevelFromSamples() {
        let level = AudioLevel(samples: squareWave(amplitude: 0.1, count: 480), sampleRate: 48_000)
        #expect(isClose(level.rms, 0.1))
        #expect(isClose(level.peak, 0.1))
        #expect(isClose(level.duration, 0.01))
        #expect(isClose(level.rmsDecibels, -20))
        #expect(isClose(level.normalized(floor: -40), 0.5))
    }
}
