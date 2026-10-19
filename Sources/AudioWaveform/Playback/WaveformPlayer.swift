import AVFAudio
import Foundation
import Observation

/// A small `AVAudioPlayer` wrapper whose `progress` a waveform can bind to: it moves while playing, and setting
/// it (by scrubbing the waveform) seeks.
///
/// ```swift
/// @State private var player = WaveformPlayer()
///
/// WaveformView(waveform: waveform, progress: $player.progress)
///     .task { try? player.load(url) }
/// ```
@MainActor
@Observable
public final class WaveformPlayer {
    /// The playback position in seconds.
    public private(set) var currentTime: TimeInterval = 0
    /// The length of the loaded file in seconds, 0 when nothing is loaded.
    public private(set) var duration: TimeInterval = 0
    /// Whether audio is playing.
    public private(set) var isPlaying = false
    /// The loaded file.
    public private(set) var url: URL?
    /// The last playback error.
    public private(set) var errorMessage: String?
    /// Starts over at the end instead of stopping.
    public var isLooping = false
    /// How often `currentTime` updates while playing, in seconds.
    public var updateInterval: TimeInterval = 1.0 / 30.0

    /// The playback position in `0...1`. Setting it seeks, so `$player.progress` is a scrubbing binding.
    public var progress: Double {
        get { duration > 0 ? min(max(currentTime / duration, 0), 1) : 0 }
        set { seek(toProgress: newValue) }
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    public init() {}

    /// Loads a file, replacing the current one. Playback stops and the position goes back to the start.
    public func load(_ url: URL) throws {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            self.player = player
            self.url = url
            duration = player.duration
            currentTime = 0
            errorMessage = nil
        } catch {
            player = nil
            self.url = nil
            duration = 0
            currentTime = 0
            errorMessage = WaveformError.unreadableFile(url.lastPathComponent).localizedDescription
            throw WaveformError.unreadableFile(url.lastPathComponent)
        }
    }

    /// Starts or resumes playback. At the end of the file, playback starts over.
    public func play() {
        guard let player else { return }
        #if os(iOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        #endif
        if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }
        player.numberOfLoops = isLooping ? -1 : 0
        guard player.play() else {
            errorMessage = "Playback could not start."
            return
        }
        errorMessage = nil
        isPlaying = true
        startTicker()
    }

    /// Pauses playback and keeps the position.
    public func pause() {
        player?.pause()
        ticker?.cancel()
        ticker = nil
        if let player {
            currentTime = player.currentTime
        }
        isPlaying = false
    }

    /// Plays when paused, pauses when playing.
    public func togglePlayback() {
        isPlaying ? pause() : play()
    }

    /// Stops playback and goes back to the start.
    public func stop() {
        player?.stop()
        player?.currentTime = 0
        ticker?.cancel()
        ticker = nil
        currentTime = 0
        isPlaying = false
    }

    /// Moves to a time in seconds, clamped to the file.
    public func seek(to time: TimeInterval) {
        guard let player, time.isFinite else { return }
        let clamped = min(max(time, 0), duration)
        player.currentTime = clamped
        currentTime = clamped
    }

    /// Moves to a position in `0...1`.
    public func seek(toProgress progress: Double) {
        guard progress.isFinite else { return }
        seek(to: min(max(progress, 0), 1) * duration)
    }

    /// Moves forwards (positive) or backwards (negative) by a number of seconds.
    public func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.updateInterval ?? 0.1
                try? await Task.sleep(for: .seconds(max(interval, 0.01)))
                guard !Task.isCancelled, let self, let player = self.player else { return }
                let desiredLoops = self.isLooping ? -1 : 0
                if player.numberOfLoops != desiredLoops {
                    player.numberOfLoops = desiredLoops
                }
                if player.isPlaying {
                    self.currentTime = player.currentTime
                } else {
                    // Reached the end: show the start, ready to play again.
                    self.currentTime = 0
                    self.isPlaying = false
                    self.ticker = nil
                    return
                }
            }
        }
    }
}
