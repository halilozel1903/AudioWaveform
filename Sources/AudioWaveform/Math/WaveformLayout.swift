import CoreGraphics

/// Geometry for drawing waveforms: where the bars go, the points of a line, and how a touch maps to progress.
/// The SwiftUI views use it, and it works just as well for a custom renderer.
public enum WaveformLayout {
    /// Where bars sit vertically.
    public enum Alignment: Sendable, Hashable {
        /// Bars rise from the bottom edge.
        case bottom
        /// Bars grow up and down from the horizontal centre line (a mirrored waveform).
        case center
    }

    /// How many bars of `barWidth` with `spacing` between them fit into `width`.
    public static func barCount(width: CGFloat, barWidth: CGFloat, spacing: CGFloat) -> Int {
        guard width > 0, barWidth > 0, width.isFinite else { return 0 }
        let gap = max(0, spacing)
        return Int(((width + gap) / (barWidth + gap)).rounded(.down))
    }

    /// One rectangle per bar, spread over the full width: the values are resampled to as many bars as fit, and
    /// each bar's height is its value (clamped into `0...1`) times the height, but at least `minimumBarHeight`.
    public static func barRects(
        values: [Float],
        size: CGSize,
        barWidth: CGFloat,
        spacing: CGFloat,
        alignment: Alignment,
        minimumBarHeight: CGFloat = 1
    ) -> [CGRect] {
        let count = barCount(width: size.width, barWidth: barWidth, spacing: spacing)
        guard count > 0, size.height > 0, !values.isEmpty else { return [] }
        let fitted = WaveformMath.clamped(WaveformMath.resample(values, to: count))
        let step = count > 1 ? (size.width - barWidth) / CGFloat(count - 1) : 0
        return fitted.enumerated().map { index, value in
            let x = count > 1 ? CGFloat(index) * step : (size.width - barWidth) / 2
            return bar(x: x, value: value, size: size, barWidth: barWidth, alignment: alignment, minimumBarHeight: minimumBarHeight)
        }
    }

    /// Bars for a live meter: one bar per value, newest on the right, pinned to the trailing edge. Only the most
    /// recent values that fit are laid out, so the history scrolls to the left as values arrive.
    public static func trailingBarRects(
        levels: [Float],
        size: CGSize,
        barWidth: CGFloat,
        spacing: CGFloat,
        alignment: Alignment,
        minimumBarHeight: CGFloat = 1
    ) -> [CGRect] {
        let count = barCount(width: size.width, barWidth: barWidth, spacing: spacing)
        guard count > 0, size.height > 0 else { return [] }
        let recent = WaveformMath.clamped(Array(levels.suffix(count)))
        let step = barWidth + max(0, spacing)
        return recent.enumerated().map { index, value in
            let x = size.width - barWidth - CGFloat(recent.count - 1 - index) * step
            return bar(x: x, value: value, size: size, barWidth: barWidth, alignment: alignment, minimumBarHeight: minimumBarHeight)
        }
    }

    /// The points of a line through the values, from the left edge to the right edge, with 0 at the bottom and 1 at
    /// the top. `inset` keeps a stroke of that width inside the bounds. At most `maximumPoints` points (at least 2).
    public static func linePoints(values: [Float], size: CGSize, maximumPoints: Int, inset: CGFloat = 0) -> [CGPoint] {
        guard !values.isEmpty, size.width > 0, size.height > 0 else { return [] }
        let count = max(2, min(values.count, maximumPoints))
        let fitted = WaveformMath.clamped(WaveformMath.resample(values, to: count))
        let usable = max(0, size.height - 2 * inset)
        return fitted.enumerated().map { index, value in
            let x = size.width * CGFloat(index) / CGFloat(count - 1)
            let y = size.height - inset - CGFloat(value) * usable
            return CGPoint(x: x, y: y)
        }
    }

    /// The playback progress (`0...1`) for a touch at `x` in a waveform `width` points wide.
    public static func progress(forX x: CGFloat, width: CGFloat) -> Double {
        guard width > 0, x.isFinite else { return 0 }
        return Double(min(max(x / width, 0), 1))
    }

    private static func bar(
        x: CGFloat,
        value: Float,
        size: CGSize,
        barWidth: CGFloat,
        alignment: Alignment,
        minimumBarHeight: CGFloat
    ) -> CGRect {
        let height = min(size.height, max(minimumBarHeight, CGFloat(value) * size.height))
        let y: CGFloat
        switch alignment {
        case .bottom: y = size.height - height
        case .center: y = (size.height - height) / 2
        }
        return CGRect(x: x, y: y, width: barWidth, height: height)
    }
}
