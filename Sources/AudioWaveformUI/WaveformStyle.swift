import AudioWaveform
import CoreGraphics

/// How a waveform is drawn.
///
/// Start from `.bars`, `.mirrored` or `.line` and adjust what you need:
///
/// ```swift
/// var thin = WaveformStyle.mirrored
/// thin.barWidth = 1.5
/// thin.spacing = 1
/// ```
public struct WaveformStyle: Hashable, Sendable {
    /// The shape of the waveform.
    public enum Kind: Hashable, Sendable {
        /// Bars rising from the bottom edge.
        case bars
        /// Bars growing up and down from the centre line, like a voice message.
        case mirrored
        /// A line through the values, with 0 at the bottom, optionally filled underneath.
        case line
    }

    public var kind: Kind
    /// The width of each bar (bars and mirrored).
    public var barWidth: CGFloat
    /// The gap between bars; the bars stretch so the waveform fills its width.
    public var spacing: CGFloat
    /// The corner radius of each bar; `nil` rounds the ends fully.
    public var cornerRadius: CGFloat?
    /// The smallest bar height, so silence still shows as a thin line.
    public var minimumBarHeight: CGFloat
    /// The stroke width of the line style.
    public var lineWidth: CGFloat
    /// Fills the area under the line with a lighter shade.
    public var fillsLine: Bool

    public init(
        kind: Kind = .mirrored,
        barWidth: CGFloat = 3,
        spacing: CGFloat = 2,
        cornerRadius: CGFloat? = nil,
        minimumBarHeight: CGFloat = 2,
        lineWidth: CGFloat = 2,
        fillsLine: Bool = true
    ) {
        self.kind = kind
        self.barWidth = barWidth
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.minimumBarHeight = minimumBarHeight
        self.lineWidth = lineWidth
        self.fillsLine = fillsLine
    }

    /// Bars rising from the bottom.
    public static let bars = WaveformStyle(kind: .bars)
    /// Bars mirrored around the centre line.
    public static let mirrored = WaveformStyle(kind: .mirrored)
    /// A filled line.
    public static let line = WaveformStyle(kind: .line)

    var barAlignment: WaveformLayout.Alignment {
        kind == .bars ? .bottom : .center
    }
}
