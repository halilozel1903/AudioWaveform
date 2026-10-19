import AudioWaveform
import AudioWaveformUI
import SwiftUI

/// A live level meter fed by the microphone, or by the selected demo track through the same input interface.
struct RecordScreen: View {
    var body: some View {
        DemoScreen("Record") {
            RecorderCard()
        }
    }
}

struct RecorderCard: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let monitor = model.monitor
        VStack(alignment: .leading, spacing: 14) {
            Picker("Input", selection: $model.inputSelection) {
                ForEach(DemoInput.allCases) { input in
                    Text(input.title).tag(input)
                }
            }
            .pickerStyle(.segmented)

            if model.input == .demoFile {
                HStack {
                    Text(model.selected.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    DemoAudioBadge()
                }
            }

            LiveWaveformView(levels: monitor.history, style: WaveformStyle(kind: .mirrored, barWidth: 3, spacing: 2), color: DemoPalette.played)
                .frame(height: 128)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            LevelIndicator(level: monitor.level, peak: monitor.peakHold)
                .frame(height: 8)

            HStack {
                Text(verbatim: decibelText(monitor.decibels))
                Spacer()
                Text(WaveformTime.format(monitor.elapsed))
            }
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)

            Button {
                model.toggleMonitoring()
            } label: {
                Label(monitor.isRunning ? "Stop" : "Start", systemImage: monitor.isRunning ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let message = monitor.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text(model.input.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
