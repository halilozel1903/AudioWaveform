import Foundation

/// Anything that delivers live audio levels: the microphone, a file played back in real time, or your own source.
///
/// `levels()` returns a stream that starts the input when it is created and stops it when the stream ends or the
/// task iterating it is cancelled. `LevelMonitor` consumes any source, so a recorder UI can run on the
/// microphone on a device and on a file in the simulator or in previews without other changes.
public protocol AudioLevelSource: Sendable {
    /// A stream of levels, one per audio buffer.
    func levels() -> AsyncThrowingStream<AudioLevel, any Error>
}
