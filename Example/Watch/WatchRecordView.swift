import AudioWaveform
import AudioWaveformUI
import SwiftUI

/// The live level meter on Apple Watch: the microphone, or the selected demo track through the same input interface.
struct WatchRecordView: View {
    var body: some View {
        WatchPage("Levels") {
            WatchRecorder()
        }
    }
}

struct WatchRecorder: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        let monitor = model.monitor
        VStack(alignment: .leading, spacing: 8) {
            LiveWaveformView(levels: monitor.history, style: WaveformStyle(kind: .mirrored, barWidth: 2.5, spacing: 1.5), color: DemoPalette.played)
                .frame(height: 56)
            LevelIndicator(level: monitor.level, peak: monitor.peakHold)
                .frame(height: 6)
            HStack {
                Text(verbatim: decibelText(monitor.decibels))
                Spacer()
                Text(WaveformTime.format(monitor.elapsed))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

            Button {
                model.toggleMonitoring()
            } label: {
                Label(monitor.isRunning ? "Stop" : "Start", systemImage: monitor.isRunning ? "stop.fill" : "record.circle")
            }
            .tint(DemoPalette.played)

            Button {
                model.inputSelection = model.input == .demoFile ? .microphone : .demoFile
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Input")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(model.input.title)
                        .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if model.input == .demoFile {
                DemoAudioBadge(compact: true)
            }
            if let message = monitor.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
