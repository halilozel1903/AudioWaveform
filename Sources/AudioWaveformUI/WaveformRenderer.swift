import AudioWaveform
import SwiftUI

/// Builds the paths of a waveform and draws them into a `GraphicsContext`.
struct WaveformRenderer {
    let fill: Path
    let stroke: Path?
    let style: WaveformStyle

    init(samples: [Float], size: CGSize, style: WaveformStyle) {
        self.style = style
        switch style.kind {
        case .bars, .mirrored:
            let rects = WaveformLayout.barRects(
                values: samples,
                size: size,
                barWidth: style.barWidth,
                spacing: style.spacing,
                alignment: style.barAlignment,
                minimumBarHeight: style.minimumBarHeight
            )
            fill = Self.barsPath(rects, cornerRadius: style.cornerRadius)
            stroke = nil
        case .line:
            let points = WaveformLayout.linePoints(
                values: samples,
                size: size,
                maximumPoints: max(2, Int(size.width / 2)),
                inset: style.lineWidth / 2
            )
            var line = Path()
            line.addLines(points)
            stroke = line
            var area = Path()
            if style.fillsLine, let first = points.first, let last = points.last {
                area.move(to: CGPoint(x: first.x, y: size.height))
                area.addLines(points)
                area.addLine(to: CGPoint(x: last.x, y: size.height))
                area.closeSubpath()
            }
            fill = area
        }
    }

    static func barsPath(_ rects: [CGRect], cornerRadius: CGFloat?) -> Path {
        var path = Path()
        for rect in rects {
            let radius = min(cornerRadius ?? rect.width / 2, rect.width / 2, rect.height / 2)
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }

    func draw(in context: GraphicsContext, color: Color) {
        switch style.kind {
        case .bars, .mirrored:
            context.fill(fill, with: .color(color))
        case .line:
            if style.fillsLine {
                context.fill(fill, with: .color(color.opacity(0.28)))
            }
            if let stroke {
                context.stroke(
                    stroke,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    /// Draws the part left of `split` in `played` and the rest in `unplayed`.
    func draw(in context: GraphicsContext, size: CGSize, split: CGFloat, played: Color, unplayed: Color) {
        let x = min(max(split, 0), size.width)
        if x < size.width {
            var right = context
            right.clip(to: Path(CGRect(x: x, y: 0, width: size.width - x, height: size.height)))
            draw(in: right, color: unplayed)
        }
        if x > 0 {
            var left = context
            left.clip(to: Path(CGRect(x: 0, y: 0, width: x, height: size.height)))
            draw(in: left, color: played)
        }
    }
}
