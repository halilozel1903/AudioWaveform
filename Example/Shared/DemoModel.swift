import AudioWaveform
import Foundation
import Observation

/// Where the recorder's levels come from.
enum DemoInput: String, CaseIterable, Identifiable {
    /// The selected demo track, read in real time by `FileLevelSource`. No microphone involved.
    case demoFile
    /// The microphone, through `MicrophoneLevelSource`.
    case microphone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .demoFile: "Demo file"
        case .microphone: "Microphone"
        }
    }

    var explanation: String {
        switch self {
        case .demoFile:
            "Levels come from the generated demo audio, read in real time through FileLevelSource, the same input interface the microphone uses. Nothing is recorded."
        case .microphone:
            "Levels come from the microphone through an AVAudioEngine tap. Nothing is recorded or stored."
        }
    }

    /// The simulator has no useful microphone, so it starts on the demo file.
    static var preferred: DemoInput {
        #if targetEnvironment(simulator)
        .demoFile
        #else
        .microphone
        #endif
    }
}

/// Loads the waveforms of the demo tracks, owns the player and the level monitor.
@MainActor
@Observable
final class DemoModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    /// The options of every waveform in the app, so the track rows' `AsyncWaveformView`s hit the same cache.
    static let options = WaveformExtractor.Options(bucketCount: 480, mode: .rms)
    static let peakOptions = WaveformExtractor.Options(bucketCount: 480, mode: .peak)

    /// Where the screenshot scenes pause the player.
    static let screenshotProgress = 0.42

    private(set) var phase: Phase = .loading
    private(set) var waveforms: [DemoTrack.ID: Waveform] = [:]
    private(set) var peakWaveforms: [DemoTrack.ID: Waveform] = [:]
    private(set) var selected: DemoTrack = DemoTrack.all[0]
    private(set) var input: DemoInput = .preferred

    /// The input picker's selection: changing it restarts a running monitor on the new input.
    var inputSelection: DemoInput {
        get { input }
        set {
            guard newValue != input else { return }
            input = newValue
            if monitor.isRunning {
                startMonitoring()
            }
        }
    }

    let player = WaveformPlayer()
    let monitor = LevelMonitor(capacity: 160, floorDecibels: -50)

    private let scene: ScreenshotScene?
    @ObservationIgnored private var resumesAfterScrubbing = false

    init(scene: ScreenshotScene?) {
        self.scene = scene
    }

    func waveform(for track: DemoTrack) -> Waveform {
        waveforms[track.id] ?? .empty
    }

    func peakWaveform(for track: DemoTrack) -> Waveform {
        peakWaveforms[track.id] ?? .empty
    }

    /// Extracts every demo track's waveform and loads the first track into the player.
    func load() async {
        phase = .loading
        do {
            for track in DemoTrack.all {
                guard let url = track.url else {
                    throw WaveformError.unreadableFile("\(track.id).caf (missing from the app bundle)")
                }
                waveforms[track.id] = try await WaveformExtractor.shared.waveform(for: url, options: Self.options)
                peakWaveforms[track.id] = try await WaveformExtractor.shared.waveform(for: url, options: Self.peakOptions)
            }
            try loadIntoPlayer(selected)
            if scene != nil {
                player.seek(toProgress: Self.screenshotProgress)
            }
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func select(_ track: DemoTrack) {
        guard track != selected else { return }
        let wasPlaying = player.isPlaying
        do {
            try loadIntoPlayer(track)
            selected = track
            if wasPlaying {
                player.play()
            }
            if monitor.isRunning, input == .demoFile {
                startMonitoring()
            }
        } catch {
            // The player shows its error message.
        }
    }

    /// Pauses while the waveform is dragged and resumes afterwards if it was playing.
    func scrubbing(_ isScrubbing: Bool) {
        if isScrubbing {
            resumesAfterScrubbing = player.isPlaying
            player.pause()
        } else if resumesAfterScrubbing {
            resumesAfterScrubbing = false
            player.play()
        }
    }

    func toggleMonitoring() {
        monitor.isRunning ? monitor.stop() : startMonitoring()
    }

    func startMonitoring() {
        switch input {
        case .demoFile:
            guard let url = selected.url else { return }
            monitor.start(FileLevelSource(url: url, loops: true))
        case .microphone:
            monitor.start(MicrophoneLevelSource())
        }
    }

    private func loadIntoPlayer(_ track: DemoTrack) throws {
        guard let url = track.url else {
            throw WaveformError.unreadableFile("\(track.id).caf")
        }
        try player.load(url)
    }
}
