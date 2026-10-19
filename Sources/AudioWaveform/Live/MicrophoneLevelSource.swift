import AVFAudio
import Foundation

/// Live levels from the microphone, measured by a tap on `AVAudioEngine`'s input node.
///
/// Iterating `levels()` asks for microphone permission (add `NSMicrophoneUsageDescription` to your Info.plist),
/// configures the audio session on iOS and watchOS, installs the tap and starts the engine. Ending the iteration
/// removes the tap and stops the engine. The stream fails with `WaveformError.microphonePermissionDenied`,
/// `.noInputDevice` or `.engineFailed`.
///
/// The simulator usually has no useful input; use `FileLevelSource` there.
public struct MicrophoneLevelSource: AudioLevelSource {
    /// Frames per tap buffer: smaller buffers mean more frequent levels.
    public var bufferSize: AVAudioFrameCount

    public init(bufferSize: AVAudioFrameCount = 2048) {
        self.bufferSize = bufferSize
    }

    public func levels() -> AsyncThrowingStream<AudioLevel, any Error> {
        let bufferSize = self.bufferSize
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let engine = InputTapEngine()
            let start = Task {
                do {
                    guard await AVAudioApplication.requestRecordPermission() else {
                        throw WaveformError.microphonePermissionDenied
                    }
                    try Task.checkCancellation()
                    try engine.start(bufferSize: bufferSize) { level in
                        continuation.yield(level)
                    }
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                start.cancel()
                engine.stop()
            }
        }
    }
}

/// Owns the engine for one microphone stream. Start and stop can arrive on different threads, so a lock guards
/// the state; a stop before the start makes the start do nothing.
private final class InputTapEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var isStopped = false

    func start(bufferSize: AVAudioFrameCount, onLevel: @escaping @Sendable (AudioLevel) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isStopped else { return }

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        #elseif os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [])
        try session.setActive(true)
        #endif

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw WaveformError.noInputDevice }
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, _ in
            onLevel(AudioLevel(measuring: buffer))
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw WaveformError.engineFailed(error.localizedDescription)
        }
        self.engine = engine
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isStopped = true
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
        #if os(iOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
