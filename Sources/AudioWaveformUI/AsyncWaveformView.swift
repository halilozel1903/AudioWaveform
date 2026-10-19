import AudioWaveform
import SwiftUI

/// Loads the waveform of an audio file with a `WaveformExtractor` and draws it.
///
/// Extraction starts when the view appears, is cancelled when it disappears or the URL changes, and comes from
/// the extractor's cache when the same file was loaded before. While loading, a flat placeholder is shown.
///
/// ```swift
/// AsyncWaveformView(url: memoURL, style: .bars)
///     .frame(height: 32)
/// ```
public struct AsyncWaveformView: View {
    private enum Phase: Equatable {
        case loading
        case loaded(Waveform)
        case failed(String)
    }

    private struct LoadKey: Hashable {
        let url: URL
        let options: WaveformExtractor.Options
    }

    private let url: URL
    private let extractor: WaveformExtractor
    private let options: WaveformExtractor.Options
    private let progress: Binding<Double>?
    private let style: WaveformStyle
    private let played: Color
    private let unplayed: Color
    private let onLoad: ((Waveform) -> Void)?

    @State private var phase: Phase = .loading

    /// - Parameters:
    ///   - progress: A binding to scrub with, or `nil` for a waveform that ignores touches.
    ///   - onLoad: Called with the waveform once it is loaded.
    public init(
        url: URL,
        extractor: WaveformExtractor = .shared,
        options: WaveformExtractor.Options = .init(),
        progress: Binding<Double>? = nil,
        style: WaveformStyle = .mirrored,
        played: Color = .accentColor,
        unplayed: Color = Color.secondary.opacity(0.35),
        onLoad: ((Waveform) -> Void)? = nil
    ) {
        self.url = url
        self.extractor = extractor
        self.options = options
        self.progress = progress
        self.style = style
        self.played = played
        self.unplayed = unplayed
        self.onLoad = onLoad
    }

    public var body: some View {
        content
            .task(id: LoadKey(url: url, options: options)) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            WaveformView(samples: Array(repeating: 0.04, count: 64), style: style, played: unplayed, unplayed: unplayed.opacity(0.5))
                .accessibilityLabel(Text("Loading waveform"))
        case let .loaded(waveform):
            if let progress {
                WaveformView(waveform: waveform, progress: progress, style: style, played: played, unplayed: unplayed)
            } else {
                WaveformView(waveform: waveform, style: style, played: played, unplayed: unplayed)
            }
        case let .failed(message):
            Label(message, systemImage: "waveform.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func load() async {
        if case .loaded = phase {
            phase = .loading
        }
        do {
            let waveform = try await extractor.waveform(for: url, options: options)
            phase = .loaded(waveform)
            onLoad?(waveform)
        } catch is CancellationError {
            // The view went away or the file changed; the next task loads again.
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
