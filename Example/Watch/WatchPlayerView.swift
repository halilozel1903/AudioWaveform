import AudioWaveform
import AudioWaveformUI
import SwiftUI

/// The selected track: a waveform you scrub by dragging or with the Digital Crown, the time, and the controls.
struct WatchPlayerView: View {
    var body: some View {
        WatchPage("Player") {
            WatchNowPlaying()
        }
    }
}

struct WatchNowPlaying: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        @Bindable var player = model.player
        VStack(alignment: .leading, spacing: 6) {
            Text(model.selected.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            DemoAudioBadge(compact: true)

            WaveformView(
                waveform: model.waveform(for: model.selected),
                progress: $player.progress,
                style: WaveformStyle(kind: .mirrored, barWidth: 2.5, spacing: 1.5),
                played: DemoPalette.played,
                unplayed: DemoPalette.unplayed,
                onEditingChanged: { model.scrubbing($0) }
            )
            .frame(height: 54)
            .focusable()
            .digitalCrownRotation(
                $player.progress,
                from: 0,
                through: 1,
                by: 0.01,
                sensitivity: .low,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )

            HStack {
                Text(WaveformTime.format(player.currentTime))
                Spacer()
                Text(WaveformTime.format(player.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack {
                Button {
                    player.skip(by: -5)
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.title3)
                }
                .accessibilityLabel(Text("Back 5 seconds"))
                Spacer()
                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 38))
                }
                .accessibilityLabel(Text(player.isPlaying ? "Pause" : "Play"))
                Spacer()
                Button {
                    player.skip(by: 5)
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.title3)
                }
                .accessibilityLabel(Text("Forward 5 seconds"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DemoPalette.played)
            .padding(.horizontal, 8)

            Text("Tracks")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            ForEach(DemoTrack.all) { track in
                Button {
                    model.select(track)
                } label: {
                    Label(track.title, systemImage: track.symbol)
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundStyle(track == model.selected ? DemoPalette.played : .primary)
                }
            }
        }
    }
}
