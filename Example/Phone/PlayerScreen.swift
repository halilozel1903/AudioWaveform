import AudioWaveform
import AudioWaveformUI
import SwiftUI

/// The selected track with a large scrubbable waveform and playback controls, and the list of demo tracks.
struct PlayerScreen: View {
    var body: some View {
        DemoScreen("Player") {
            NowPlayingCard()
            TrackListCard()
            Text("All audio in this app is synthesized by scripts/generate-demo-audio.py from sine waves. Drag across a waveform to scrub.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

struct NowPlayingCard: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        @Bindable var player = model.player
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selected.title)
                        .font(.title3.weight(.bold))
                    Text(model.selected.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                DemoAudioBadge()
            }

            WaveformView(
                waveform: model.waveform(for: model.selected),
                progress: $player.progress,
                style: WaveformStyle(kind: .mirrored, barWidth: 3, spacing: 2),
                played: DemoPalette.played,
                unplayed: DemoPalette.unplayed,
                onEditingChanged: { model.scrubbing($0) }
            )
            .frame(height: 128)

            HStack {
                Text(WaveformTime.format(player.currentTime))
                Spacer()
                Text(WaveformTime.remaining(player.currentTime, of: player.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            HStack(spacing: 40) {
                Spacer()
                Button {
                    player.skip(by: -5)
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Back 5 seconds"))
                Button {
                    player.togglePlayback()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                }
                .accessibilityLabel(Text(player.isPlaying ? "Pause" : "Play"))
                Button {
                    player.skip(by: 5)
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.title2)
                }
                .accessibilityLabel(Text("Forward 5 seconds"))
                Spacer()
            }
            .buttonStyle(.plain)
            .foregroundStyle(DemoPalette.played)

            if let message = player.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// One row per demo track with a small waveform, loaded by `AsyncWaveformView` from the extractor's cache.
struct TrackListCard: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        DemoCard("Demo tracks", caption: "\(DemoTrack.all.count) generated") {
            VStack(spacing: 0) {
                ForEach(DemoTrack.all) { track in
                    let isSelected = track == model.selected
                    Button {
                        model.select(track)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: track.symbol)
                                .font(.body)
                                .frame(width: 26)
                                .foregroundStyle(isSelected ? DemoPalette.played : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(WaveformTime.format(model.waveform(for: track).duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 128, alignment: .leading)
                            if let url = track.url {
                                AsyncWaveformView(
                                    url: url,
                                    options: DemoModel.options,
                                    style: WaveformStyle(kind: .mirrored, barWidth: 2, spacing: 1.5),
                                    unplayed: isSelected ? DemoPalette.played.opacity(0.85) : DemoPalette.unplayed
                                )
                                .frame(height: 30)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    if track != DemoTrack.all.last {
                        Divider()
                    }
                }
            }
        }
    }
}
