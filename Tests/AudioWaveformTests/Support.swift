import AVFAudio
import Foundation
@testable import AudioWaveform

/// Whether two float arrays have the same length and match within `tolerance`.
func isClose(_ actual: [Float], _ expected: [Float], tolerance: Float = 1e-4) -> Bool {
    guard actual.count == expected.count else { return false }
    return zip(actual, expected).allSatisfy { abs($0 - $1) <= tolerance }
}

func isClose(_ actual: Float, _ expected: Float, tolerance: Float = 1e-4) -> Bool {
    abs(actual - expected) <= tolerance
}

func isClose(_ actual: Double, _ expected: Double, tolerance: Double = 1e-6) -> Bool {
    abs(actual - expected) <= tolerance
}

/// Writes mono 32-bit float samples to a new .caf file in a temporary folder and returns its URL. The file is
/// closed when this returns, so it can be read right away.
func writeTemporaryAudio(_ samples: [Float], sampleRate: Double, name: String = UUID().uuidString) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AudioWaveformTests", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(name).caf")
    try? FileManager.default.removeItem(at: url)
    try writeAudio(samples, sampleRate: sampleRate, to: url)
    return url
}

private func writeAudio(_ samples: [Float], sampleRate: Double, to url: URL) throws {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
          let channel = buffer.floatChannelData?[0]
    else {
        throw WaveformError.bufferAllocationFailed
    }
    for (index, sample) in samples.enumerated() {
        channel[index] = sample
    }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    try file.write(from: buffer)
}

/// A signal that alternates between +amplitude and -amplitude: its RMS and peak are both `amplitude`.
func squareWave(amplitude: Float, count: Int) -> [Float] {
    (0..<count).map { $0 % 2 == 0 ? amplitude : -amplitude }
}

/// A source that delivers fixed levels and finishes.
struct StubLevelSource: AudioLevelSource {
    let values: [AudioLevel]

    func levels() -> AsyncThrowingStream<AudioLevel, any Error> {
        let values = self.values
        return AsyncThrowingStream { continuation in
            for value in values {
                continuation.yield(value)
            }
            continuation.finish()
        }
    }
}

/// A source that fails right away.
struct FailingLevelSource: AudioLevelSource {
    func levels() -> AsyncThrowingStream<AudioLevel, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: WaveformError.microphonePermissionDenied)
        }
    }
}
