import AudioWaveform
import SwiftUI

/// Draws a waveform with the played part in one colour and the rest in another. With a progress binding, a drag
/// across the waveform scrubs.
///
/// ```swift
/// @State private var player = WaveformPlayer()
///
/// WaveformView(waveform: waveform, progress: $player.progress, style: .mirrored, played: .orange)
///     .frame(height: 80)
/// ```
public struct WaveformView: View {
    private let samples: [Float]
    private let binding: Binding<Double>?
    private let fixedProgress: Double
    private let style: WaveformStyle
    private let played: Color
    private let unplayed: Color
    private let onEditingChanged: (Bool) -> Void

    @State private var isScrubbing = false

    /// A scrubbable waveform. Dragging sets `progress` (`0...1`); `onEditingChanged` reports when a drag starts
    /// (`true`) and ends (`false`), for example to pause playback while scrubbing.
    public init(
        samples: [Float],
        progress: Binding<Double>,
        style: WaveformStyle = .mirrored,
        played: Color = .accentColor,
        unplayed: Color = Color.secondary.opacity(0.35),
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.samples = samples
        self.binding = progress
        self.fixedProgress = 0
        self.style = style
        self.played = played
        self.unplayed = unplayed
        self.onEditingChanged = onEditingChanged
    }

    /// A waveform that shows a fixed progress and ignores touches.
    public init(
        samples: [Float],
        progress: Double = 0,
        style: WaveformStyle = .mirrored,
        played: Color = .accentColor,
        unplayed: Color = Color.secondary.opacity(0.35)
    ) {
        self.samples = samples
        self.binding = nil
        self.fixedProgress = progress
        self.style = style
        self.played = played
        self.unplayed = unplayed
        self.onEditingChanged = { _ in }
    }

    /// A scrubbable waveform of an extracted `Waveform`.
    public init(
        waveform: Waveform,
        progress: Binding<Double>,
        style: WaveformStyle = .mirrored,
        played: Color = .accentColor,
        unplayed: Color = Color.secondary.opacity(0.35),
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(
            samples: waveform.samples,
            progress: progress,
            style: style,
            played: played,
            unplayed: unplayed,
            onEditingChanged: onEditingChanged
        )
    }

    /// A read-only waveform of an extracted `Waveform`.
    public init(
        waveform: Waveform,
        progress: Double = 0,
        style: WaveformStyle = .mirrored,
        played: Color = .accentColor,
        unplayed: Color = Color.secondary.opacity(0.35)
    ) {
        self.init(samples: waveform.samples, progress: progress, style: style, played: played, unplayed: unplayed)
    }

    private var progress: Double {
        let value = binding?.wrappedValue ?? fixedProgress
        return value.isFinite ? min(max(value, 0), 1) : 0
    }

    public var body: some View {
        let samples = self.samples
        let style = self.style
        let played = self.played
        let unplayed = self.unplayed
        let progress = self.progress
        GeometryReader { proxy in
            Canvas { context, size in
                let renderer = WaveformRenderer(samples: samples, size: size, style: style)
                renderer.draw(in: context, size: size, split: size.width * CGFloat(progress), played: played, unplayed: unplayed)
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: proxy.size.width), including: binding == nil ? GestureMask.none : GestureMask.all)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Waveform"))
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent played"))
        .accessibilityAdjustableAction { direction in
            guard let binding else { return }
            switch direction {
            case .increment:
                binding.wrappedValue = min(1, progress + 0.05)
            case .decrement:
                binding.wrappedValue = max(0, progress - 0.05)
            @unknown default:
                break
            }
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let binding else { return }
                if !isScrubbing {
                    isScrubbing = true
                    onEditingChanged(true)
                }
                binding.wrappedValue = WaveformLayout.progress(forX: value.location.x, width: width)
            }
            .onEnded { value in
                guard let binding else { return }
                binding.wrappedValue = WaveformLayout.progress(forX: value.location.x, width: width)
                if isScrubbing {
                    isScrubbing = false
                    onEditingChanged(false)
                }
            }
    }
}
