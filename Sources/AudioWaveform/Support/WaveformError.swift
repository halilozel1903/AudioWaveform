import Foundation

/// Errors from reading audio, the microphone and playback.
public enum WaveformError: Error, Sendable, Equatable, LocalizedError {
    /// The file could not be opened as audio. The associated value is the file name.
    case unreadableFile(String)
    /// The file holds no audio frames.
    case emptyFile
    /// An audio buffer could not be created for the file's format.
    case bufferAllocationFailed
    /// The user did not allow microphone access.
    case microphonePermissionDenied
    /// The device has no audio input.
    case noInputDevice
    /// The audio engine could not start. The associated value is the system's message.
    case engineFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unreadableFile(name): "\(name) could not be read as audio."
        case .emptyFile: "The audio file is empty."
        case .bufferAllocationFailed: "Could not allocate an audio buffer."
        case .microphonePermissionDenied: "Microphone access is off. Turn it on in Settings to see live levels."
        case .noInputDevice: "This device has no audio input."
        case let .engineFailed(message): "The audio engine could not start: \(message)"
        }
    }
}
