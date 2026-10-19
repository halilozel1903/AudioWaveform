import AVFAudio
import Foundation

/// Reads an audio file with `AVAudioFile` and reduces it to a `Waveform`, chunk by chunk.
///
/// This is the synchronous work behind `WaveformExtractor`. It checks for task cancellation between chunks, so
/// it stops early when called from a cancelled task. Channels are averaged into mono.
public enum AudioFileReader {
    public static func waveform(of url: URL, options: WaveformExtractor.Options = .init()) throws -> Waveform {
        try Task.checkCancellation()
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw WaveformError.unreadableFile(url.lastPathComponent)
        }
        let format = file.processingFormat
        let totalFrames = Int(file.length)
        guard totalFrames > 0, format.sampleRate > 0 else { throw WaveformError.emptyFile }
        let framesPerRead = max(1, options.framesPerRead)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerRead) else {
            throw WaveformError.bufferAllocationFailed
        }

        var accumulator = BucketAccumulator(bucketCount: options.bucketCount, totalSamples: totalFrames)
        let channelCount = Int(format.channelCount)
        while file.framePosition < file.length {
            try Task.checkCancellation()
            do {
                try file.read(into: buffer, frameCount: framesPerRead)
            } catch {
                // Compressed files can announce a slightly longer length than they decode to; keep what was read.
                if accumulator.processedSamples > 0 { break }
                throw WaveformError.unreadableFile(url.lastPathComponent)
            }
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            guard let channels = buffer.floatChannelData else { throw WaveformError.bufferAllocationFailed }
            if channelCount == 1 {
                accumulator.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: frames))
            } else {
                let scale = 1 / Float(channelCount)
                for frame in 0..<frames {
                    var sum: Float = 0
                    for channel in 0..<channelCount {
                        sum += channels[channel][frame]
                    }
                    accumulator.append(sum * scale)
                }
            }
        }

        let values = accumulator.values(for: options.mode)
        return Waveform(
            samples: options.normalizes ? WaveformMath.normalize(values) : WaveformMath.clamped(values),
            duration: Double(totalFrames) / format.sampleRate,
            sampleRate: format.sampleRate,
            mode: options.mode
        )
    }
}
