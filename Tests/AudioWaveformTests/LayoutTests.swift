import CoreGraphics
import Testing
@testable import AudioWaveform

@Suite("Layout and formatting")
struct LayoutTests {
    @Test func barCountFitsBarsAndGaps() {
        // 2 + 1 + 2 + 1 + 2 = 8 points fit into 10; a fourth bar would need 11.
        #expect(WaveformLayout.barCount(width: 10, barWidth: 2, spacing: 1) == 3)
        #expect(WaveformLayout.barCount(width: 11, barWidth: 2, spacing: 1) == 4)
        #expect(WaveformLayout.barCount(width: 1, barWidth: 2, spacing: 1) == 0)
        #expect(WaveformLayout.barCount(width: 100, barWidth: 0, spacing: 1) == 0)
    }

    @Test func bottomAlignedBarsSpanTheWidth() {
        let rects = WaveformLayout.barRects(
            values: [0.5, 1, 0],
            size: CGSize(width: 10, height: 20),
            barWidth: 2,
            spacing: 1,
            alignment: .bottom,
            minimumBarHeight: 1
        )
        #expect(rects.count == 3)
        #expect(rects[0] == CGRect(x: 0, y: 10, width: 2, height: 10))
        #expect(rects[1] == CGRect(x: 4, y: 0, width: 2, height: 20))
        #expect(rects[2] == CGRect(x: 8, y: 19, width: 2, height: 1))
    }

    @Test func mirroredBarsAreCentred() {
        let rects = WaveformLayout.barRects(
            values: [0.5],
            size: CGSize(width: 2, height: 20),
            barWidth: 2,
            spacing: 1,
            alignment: .center
        )
        #expect(rects == [CGRect(x: 0, y: 5, width: 2, height: 10)])
    }

    @Test func barsResampleToWhatFits() {
        let values = (0..<100).map { Float($0) / 99 }
        let rects = WaveformLayout.barRects(
            values: values,
            size: CGSize(width: 10, height: 10),
            barWidth: 2,
            spacing: 1,
            alignment: .bottom
        )
        #expect(rects.count == 3)
        // The last group holds the loudest value, 1.
        #expect(rects[2].height == 10)
    }

    @Test func liveBarsArePinnedToTheTrailingEdge() {
        let rects = WaveformLayout.trailingBarRects(
            levels: [1, 0.5],
            size: CGSize(width: 10, height: 10),
            barWidth: 2,
            spacing: 1,
            alignment: .bottom
        )
        #expect(rects == [
            CGRect(x: 5, y: 0, width: 2, height: 10),
            CGRect(x: 8, y: 5, width: 2, height: 5),
        ])
    }

    @Test func liveBarsKeepOnlyTheNewestLevelsThatFit() {
        let rects = WaveformLayout.trailingBarRects(
            levels: [1, 1, 1, 1, 0.25],
            size: CGSize(width: 10, height: 10),
            barWidth: 2,
            spacing: 1,
            alignment: .bottom
        )
        #expect(rects.count == 3)
        #expect(rects.first?.minX == 2)
        #expect(rects.last?.height == 2.5)
    }

    @Test func linePointsRunFromEdgeToEdge() {
        let points = WaveformLayout.linePoints(values: [0, 1, 0.5], size: CGSize(width: 100, height: 10), maximumPoints: 10)
        #expect(points == [CGPoint(x: 0, y: 10), CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 5)])
    }

    @Test func linePointsRespectTheInsetAndTheLimit() {
        let points = WaveformLayout.linePoints(values: [1, 1, 1, 1], size: CGSize(width: 30, height: 10), maximumPoints: 2, inset: 1)
        #expect(points == [CGPoint(x: 0, y: 1), CGPoint(x: 30, y: 1)])
    }

    @Test(arguments: [(-5.0, 0.0), (0.0, 0.0), (50.0, 0.25), (200.0, 1.0), (500.0, 1.0)] as [(CGFloat, Double)])
    func touchMapsToProgress(x: CGFloat, expected: Double) {
        #expect(WaveformLayout.progress(forX: x, width: 200) == expected)
    }

    @Test func progressWithoutWidthIsZero() {
        #expect(WaveformLayout.progress(forX: 10, width: 0) == 0)
    }

    @Test func timeFormatting() {
        #expect(WaveformTime.format(0) == "0:00")
        #expect(WaveformTime.format(7.9) == "0:07")
        #expect(WaveformTime.format(65) == "1:05")
        #expect(WaveformTime.format(600) == "10:00")
        #expect(WaveformTime.format(3723) == "1:02:03")
        #expect(WaveformTime.format(-3) == "0:00")
        #expect(WaveformTime.format(.nan) == "0:00")
        #expect(WaveformTime.remaining(5, of: 28) == "-0:23")
        #expect(WaveformTime.remaining(30, of: 28) == "-0:00")
    }
}
