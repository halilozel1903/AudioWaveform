import AVFAudio
import Foundation

/// Extracts waveforms from audio files off the main thread, and caches the results.
///
/// ```swift
/// let waveform = try await WaveformExtractor.shared.waveform(for: url, bucketCount: 256)
/// ```
///
/// Extraction runs on a background task and stops as soon as the calling task is cancelled (for example when the
/// view that started it with `.task` disappears). Results are cached per file URL and options, up to
/// `countLimit` waveforms; the least recently used one is dropped first.
public actor WaveformExtractor {
    /// How a file is turned into a waveform.
    public struct Options: Sendable, Hashable {
        /// The number of values to produce (fewer for very short files).
        public var bucketCount: Int
        /// RMS or peak values.
        public var mode: WaveformSampleMode
        /// Scales the result so its loudest bucket is 1. Turn off to keep absolute levels (full scale is 1).
        public var normalizes: Bool
        /// Frames read per chunk; cancellation is checked between chunks.
        public var framesPerRead: AVAudioFrameCount

        public init(
            bucketCount: Int = 512,
            mode: WaveformSampleMode = .rms,
            normalizes: Bool = true,
            framesPerRead: AVAudioFrameCount = 32_768
        ) {
            self.bucketCount = bucketCount
            self.mode = mode
            self.normalizes = normalizes
            self.framesPerRead = framesPerRead
        }
    }

    private struct Key: Hashable {
        let url: URL
        let options: Options
    }

    /// A shared extractor with the default cache size.
    public static let shared = WaveformExtractor()

    /// The maximum number of cached waveforms.
    public let countLimit: Int

    private var cache: [Key: Waveform] = [:]
    private var recency: [Key] = []

    public init(countLimit: Int = 32) {
        self.countLimit = max(0, countLimit)
    }

    /// The waveform of the audio file at `url`, from the cache or freshly extracted.
    ///
    /// - Throws: `WaveformError` when the file cannot be read, `CancellationError` when the task is cancelled.
    public func waveform(for url: URL, options: Options = Options()) async throws -> Waveform {
        try Task.checkCancellation()
        let key = Key(url: url.standardizedFileURL, options: options)
        if let cached = cache[key] {
            touch(key)
            return cached
        }
        let work = Task.detached(priority: .userInitiated) {
            try AudioFileReader.waveform(of: url, options: options)
        }
        let waveform = try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
        try Task.checkCancellation()
        store(waveform, for: key)
        return waveform
    }

    /// The waveform of the audio file at `url` with `bucketCount` values.
    public func waveform(for url: URL, bucketCount: Int, mode: WaveformSampleMode = .rms) async throws -> Waveform {
        try await waveform(for: url, options: Options(bucketCount: bucketCount, mode: mode))
    }

    /// The cached waveform, if there is one; never reads the file.
    public func cachedWaveform(for url: URL, options: Options = Options()) -> Waveform? {
        cache[Key(url: url.standardizedFileURL, options: options)]
    }

    /// The number of cached waveforms.
    public var cachedCount: Int { cache.count }

    /// Drops every cached waveform of the file at `url`, for example after the file changed.
    public func removeWaveforms(for url: URL) {
        let standardized = url.standardizedFileURL
        cache = cache.filter { $0.key.url != standardized }
        recency.removeAll { $0.url == standardized }
    }

    /// Empties the cache.
    public func removeAll() {
        cache.removeAll()
        recency.removeAll()
    }

    private func touch(_ key: Key) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    private func store(_ waveform: Waveform, for key: Key) {
        guard countLimit > 0 else { return }
        cache[key] = waveform
        touch(key)
        while recency.count > countLimit {
            let oldest = recency.removeFirst()
            cache[oldest] = nil
        }
    }
}
