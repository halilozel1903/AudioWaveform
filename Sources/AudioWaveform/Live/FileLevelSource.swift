import AVFAudio
import Foundation

/// Live levels read from an audio file, paced like a real input: a level every `interval` seconds of audio.
///
/// It goes through the same `AudioLevelSource` interface as `MicrophoneLevelSource`, so a recorder UI can be
/// driven by a file in the simulator, in previews, in UI tests or in a demo, without a microphone. Nothing is
/// played out loud; only levels are produced.
public struct FileLevelSource: AudioLevelSource {
    /// The audio file.
    public var url: URL
    /// Seconds of audio per level.
    public var interval: TimeInterval
    /// Starts over at the end instead of finishing.
    public var loops: Bool
    /// Waits `interval` between levels, like a live input. Turn off to read as fast as possible (tests).
    public var paced: Bool

    public init(url: URL, interval: TimeInterval = 0.05, loops: Bool = true, paced: Bool = true) {
        self.url = url
        self.interval = interval
        self.loops = loops
        self.paced = paced
    }

    public func levels() -> AsyncThrowingStream<AudioLevel, any Error> {
        let source = self
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let reader = Task.detached(priority: .userInitiated) {
                do {
                    try await source.run { continuation.yield($0) }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                reader.cancel()
            }
        }
    }

    private func run(_ emit: (AudioLevel) -> Void) async throws {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw WaveformError.unreadableFile(url.lastPathComponent)
        }
        let format = file.processingFormat
        guard file.length > 0, format.sampleRate > 0 else { throw WaveformError.emptyFile }
        let frames = AVAudioFrameCount(max(1, (format.sampleRate * max(interval, 0.001)).rounded()))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw WaveformError.bufferAllocationFailed
        }
        let clock = ContinuousClock()
        var deadline = clock.now
        while true {
            try Task.checkCancellation()
            if file.framePosition >= file.length {
                guard loops else { return }
                file.framePosition = 0
            }
            do {
                try file.read(into: buffer, frameCount: frames)
            } catch {
                guard loops else { return }
                file.framePosition = 0
                continue
            }
            if buffer.frameLength == 0 {
                guard loops else { return }
                file.framePosition = 0
                continue
            }
            let level = AudioLevel(measuring: buffer)
            emit(level)
            if paced {
                deadline = deadline.advanced(by: .seconds(level.duration))
                try await Task.sleep(until: deadline, clock: clock)
            }
        }
    }
}
