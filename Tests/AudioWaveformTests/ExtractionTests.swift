import Foundation
import Testing
@testable import AudioWaveform

/// End-to-end tests that write real audio files with AVAudioFile and read them back.
@Suite("Extraction")
struct ExtractionTests {
    @Test func extractsRmsBucketsFromAFile() throws {
        // One second at 8 kHz: half a second at 0.5, then half a second at 0.25.
        let url = try writeTemporaryAudio(
            squareWave(amplitude: 0.5, count: 4000) + squareWave(amplitude: 0.25, count: 4000),
            sampleRate: 8000
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let raw = try AudioFileReader.waveform(of: url, options: .init(bucketCount: 2, normalizes: false, framesPerRead: 1000))
        #expect(isClose(raw.samples, [0.5, 0.25]))
        #expect(isClose(raw.duration, 1))
        #expect(raw.sampleRate == 8000)
        #expect(raw.mode == .rms)

        let normalized = try AudioFileReader.waveform(of: url, options: .init(bucketCount: 2))
        #expect(isClose(normalized.samples, [1, 0.5]))
    }

    @Test func chunkSizeDoesNotChangeTheResult() throws {
        let samples = (0..<5000).map { index in Float(sin(Double(index) * 0.01)) * Float(index % 700) / 700 }
        let url = try writeTemporaryAudio(samples, sampleRate: 8000)
        defer { try? FileManager.default.removeItem(at: url) }

        let small = try AudioFileReader.waveform(of: url, options: .init(bucketCount: 50, mode: .peak, framesPerRead: 33))
        let large = try AudioFileReader.waveform(of: url, options: .init(bucketCount: 50, mode: .peak, framesPerRead: 8192))
        #expect(small.samples.count == 50)
        #expect(isClose(small.samples, large.samples))
        #expect(isClose(small.samples, WaveformMath.normalize(WaveformMath.buckets(samples, count: 50, mode: .peak))))
    }

    @Test func unreadableFilesThrow() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-audio-\(UUID().uuidString).caf")
        try Data("not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: WaveformError.self) {
            try AudioFileReader.waveform(of: url)
        }
    }

    @Test func extractorCachesResults() async throws {
        let url = try writeTemporaryAudio(squareWave(amplitude: 0.5, count: 800), sampleRate: 8000)
        let extractor = WaveformExtractor()
        let first = try await extractor.waveform(for: url, bucketCount: 10)
        try FileManager.default.removeItem(at: url)

        // The file is gone, so only the cache can answer.
        let second = try await extractor.waveform(for: url, bucketCount: 10)
        #expect(first == second)
        #expect(await extractor.cachedCount == 1)
        #expect(await extractor.cachedWaveform(for: url, options: .init(bucketCount: 10)) == first)

        // Other options are a different entry, and need the file.
        await #expect(throws: WaveformError.self) {
            try await extractor.waveform(for: url, bucketCount: 20)
        }
        await extractor.removeWaveforms(for: url)
        #expect(await extractor.cachedCount == 0)
    }

    @Test func extractorEvictsTheLeastRecentlyUsedWaveform() async throws {
        let urls = try (0..<3).map { _ in try writeTemporaryAudio(squareWave(amplitude: 0.5, count: 200), sampleRate: 8000) }
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }
        let extractor = WaveformExtractor(countLimit: 2)
        _ = try await extractor.waveform(for: urls[0], bucketCount: 4)
        _ = try await extractor.waveform(for: urls[1], bucketCount: 4)
        _ = try await extractor.waveform(for: urls[0], bucketCount: 4)   // urls[0] is now the most recent
        _ = try await extractor.waveform(for: urls[2], bucketCount: 4)   // evicts urls[1]
        #expect(await extractor.cachedCount == 2)
        #expect(await extractor.cachedWaveform(for: urls[0], options: .init(bucketCount: 4)) != nil)
        #expect(await extractor.cachedWaveform(for: urls[1], options: .init(bucketCount: 4)) == nil)
        #expect(await extractor.cachedWaveform(for: urls[2], options: .init(bucketCount: 4)) != nil)
    }

    @Test func cancellingStopsExtraction() async throws {
        // 30 seconds at 8 kHz read 64 frames at a time: thousands of chunks, far more than the time to cancel.
        let url = try writeTemporaryAudio(squareWave(amplitude: 0.5, count: 240_000), sampleRate: 8000)
        defer { try? FileManager.default.removeItem(at: url) }
        let extractor = WaveformExtractor()
        let options = WaveformExtractor.Options(bucketCount: 100, framesPerRead: 64)

        let task = Task {
            try await extractor.waveform(for: url, options: options)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(await extractor.cachedCount == 0)
    }

    @Test func fileLevelSourceReadsTheWholeFile() async throws {
        // One second at 8 kHz in 50 ms levels: 20 levels of 400 frames.
        let url = try writeTemporaryAudio(squareWave(amplitude: 0.1, count: 8000), sampleRate: 8000)
        defer { try? FileManager.default.removeItem(at: url) }
        let source = FileLevelSource(url: url, interval: 0.05, loops: false, paced: false)
        var levels: [AudioLevel] = []
        for try await level in source.levels() {
            levels.append(level)
        }
        #expect(levels.count == 20)
        #expect(isClose(levels.reduce(0) { $0 + $1.duration }, 1))
        #expect(levels.allSatisfy { isClose($0.rms, 0.1) })
    }

    @Test func fileLevelSourceFailsForMissingFiles() async {
        let source = FileLevelSource(url: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).caf"), paced: false)
        await #expect(throws: WaveformError.self) {
            for try await _ in source.levels() {}
        }
    }
}

@Suite("Level monitor")
@MainActor
struct LevelMonitorTests {
    private func waitUntilStopped(_ monitor: LevelMonitor) async throws {
        var waited = 0
        while monitor.isRunning && waited < 400 {
            try await Task.sleep(for: .milliseconds(10))
            waited += 1
        }
    }

    @Test func collectsHistoryLevelsAndElapsedTime() async throws {
        let monitor = LevelMonitor(capacity: 3, floorDecibels: -60)
        let loud = AudioLevel(rms: 1, peak: 1, duration: 0.1)
        let quiet = AudioLevel(rms: 0.001, peak: 0.001, duration: 0.1)   // -60 dB, the floor
        monitor.start(StubLevelSource(values: [loud, loud, quiet, loud, quiet]))
        try await waitUntilStopped(monitor)

        #expect(!monitor.isRunning)
        #expect(isClose(monitor.history, [0, 1, 0]))
        #expect(isClose(monitor.elapsed, 0.5))
        #expect(isClose(monitor.decibels, -60))
        #expect(monitor.peakHold < 1)
        #expect(monitor.errorMessage == nil)
    }

    @Test func reportsSourceErrors() async throws {
        let monitor = LevelMonitor()
        monitor.start(FailingLevelSource())
        try await waitUntilStopped(monitor)
        #expect(!monitor.isRunning)
        #expect(monitor.errorMessage == WaveformError.microphonePermissionDenied.errorDescription)
    }

    @Test func receiveSmoothsTheLevelButNotTheHistory() {
        let monitor = LevelMonitor(capacity: 10, floorDecibels: -50)
        monitor.receive(AudioLevel(rms: 1, peak: 1, duration: 0.05))
        #expect(monitor.history == [1])
        #expect(isClose(monitor.level, 0.6))
        #expect(monitor.peakHold == 1)
        monitor.reset()
        #expect(monitor.history.isEmpty)
        #expect(monitor.elapsed == 0)
    }
}
