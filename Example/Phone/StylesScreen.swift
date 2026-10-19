import AudioWaveform
import AudioWaveformUI
import SwiftUI

/// The selected track in every style. All cards bind to the same player, so dragging any of them scrubs them all.
struct StylesScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        @Bindable var player = model.player
        let waveform = model.waveform(for: model.selected)
        DemoScreen("Styles") {
            HStack {
                Text(model.selected.title)
                    .font(.headline)
                Spacer()
                DemoAudioBadge()
            }
            .padding(.horizontal, 4)

            DemoCard("Mirrored", caption: ".mirrored", tint: DemoPalette.played) {
                WaveformView(waveform: waveform, progress: $player.progress, style: .mirrored, played: DemoPalette.played, unplayed: DemoPalette.unplayed)
                    .frame(height: 56)
            }

            DemoCard("Bars", caption: ".bars", tint: DemoPalette.teal) {
                WaveformView(
                    waveform: waveform,
                    progress: $player.progress,
                    style: WaveformStyle(kind: .bars, barWidth: 4, spacing: 2, cornerRadius: 1.5),
                    played: DemoPalette.teal,
                    unplayed: DemoPalette.unplayed
                )
                .frame(height: 44)
            }

            DemoCard("Line", caption: ".line", tint: DemoPalette.violet) {
                WaveformView(waveform: waveform, progress: $player.progress, style: .line, played: DemoPalette.violet, unplayed: DemoPalette.unplayed)
                    .frame(height: 44)
            }

            DemoCard("Thin mirrored", caption: "barWidth 1.5, spacing 1", tint: DemoPalette.yellow) {
                WaveformView(
                    waveform: waveform,
                    progress: $player.progress,
                    style: WaveformStyle(kind: .mirrored, barWidth: 1.5, spacing: 1, minimumBarHeight: 1),
                    played: DemoPalette.yellow,
                    unplayed: DemoPalette.unplayed
                )
                .frame(height: 36)
            }

            DemoCard("RMS and peak buckets", caption: "WaveformSampleMode") {
                VStack(alignment: .leading, spacing: 6) {
                    ModeRow(label: "RMS") {
                        WaveformView(waveform: waveform, progress: $player.progress, style: .bars, played: DemoPalette.played, unplayed: DemoPalette.unplayed)
                    }
                    ModeRow(label: "Peak") {
                        WaveformView(
                            waveform: model.peakWaveform(for: model.selected),
                            progress: $player.progress,
                            style: .bars,
                            played: DemoPalette.played,
                            unplayed: DemoPalette.unplayed
                        )
                    }
                }
            }

            Text("All cards share one player: drag any to scrub.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

private struct ModeRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            content
                .frame(height: 30)
        }
    }
}
