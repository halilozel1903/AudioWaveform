import AudioWaveform
import SwiftUI

/// A scrolling waveform of live levels, newest on the right: one bar per level, older bars fading out.
///
/// Feed it `LevelMonitor.history`. The line style draws as mirrored bars here.
///
/// ```swift
/// LiveWaveformView(levels: monitor.history, color: .red)
///     .frame(height: 80)
/// ```
public struct LiveWaveformView: View {
    private let levels: [Float]
    private let style: WaveformStyle
    private let color: Color
    private let fadesOlderLevels: Bool

    public init(levels: [Float], style: WaveformStyle = .mirrored, color: Color = .accentColor, fadesOlderLevels: Bool = true) {
        self.levels = levels
        self.style = style
        self.color = color
        self.fadesOlderLevels = fadesOlderLevels
    }

    public var body: some View {
        let levels = self.levels
        let style = self.style
        let color = self.color
        let fades = fadesOlderLevels
        Canvas { context, size in
            let rects = WaveformLayout.trailingBarRects(
                levels: levels,
                size: size,
                barWidth: style.barWidth,
                spacing: style.spacing,
                alignment: style.barAlignment,
                minimumBarHeight: style.minimumBarHeight
            )
            let count = rects.count
            for (index, rect) in rects.enumerated() {
                let age = count > 1 ? Double(index) / Double(count - 1) : 1
                let opacity = fades ? 0.3 + 0.7 * age : 1
                context.fill(
                    WaveformRenderer.barsPath([rect], cornerRadius: style.cornerRadius),
                    with: .color(color.opacity(opacity))
                )
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Live audio level"))
    }
}

/// A horizontal level meter: green to yellow to red, filled to `level`, with a tick at `peak`. Both in `0...1`.
public struct LevelIndicator: View {
    private let level: Float
    private let peak: Float?

    public init(level: Float, peak: Float? = nil) {
        self.level = level
        self.peak = peak
    }

    public var body: some View {
        let level = CGFloat(min(max(self.level.isFinite ? self.level : 0, 0), 1))
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                Capsule()
                    .fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * level)
                    }
                if let peak, peak > 0 {
                    let x = width * CGFloat(min(max(peak, 0), 1))
                    Capsule()
                        .fill(.primary)
                        .frame(width: 2)
                        .offset(x: min(max(x - 1, 0), max(width - 2, 0)))
                }
            }
        }
        .frame(minHeight: 4)
        .accessibilityElement()
        .accessibilityLabel(Text("Level"))
        .accessibilityValue(Text("\(Int((level * 100).rounded())) percent"))
    }
}
