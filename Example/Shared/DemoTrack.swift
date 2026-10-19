import Foundation
import SwiftUI

/// The demo tracks bundled with the app. All of them are synthesized by scripts/generate-demo-audio.py (sine
/// waves only), so they are generated demo audio, not recordings.
struct DemoTrack: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String

    static let all: [DemoTrack] = [
        DemoTrack(
            id: "chord-progression",
            title: "Chord Progression",
            subtitle: "Pad, pluck and pulse in C",
            symbol: "pianokeys"
        ),
        DemoTrack(
            id: "arpeggio",
            title: "Plucked Arpeggio",
            subtitle: "A minor pentatonic",
            symbol: "music.note"
        ),
        DemoTrack(
            id: "swells",
            title: "Tone Swells",
            subtitle: "Slow swells with tremolo",
            symbol: "water.waves"
        ),
    ]

    /// The bundled .caf file, or `nil` when it is missing from the app bundle.
    var url: URL? {
        Bundle.main.url(forResource: id, withExtension: "caf")
    }
}

/// "-18 dB", or "-∞ dB" for silence.
func decibelText(_ decibels: Float) -> String {
    decibels <= -100 ? "-∞ dB" : "\(Int(decibels.rounded())) dB"
}

/// The colours of the demo apps.
enum DemoPalette {
    static let played = Color(red: 1.0, green: 0.45, blue: 0.25)
    static let teal = Color(red: 0.2, green: 0.8, blue: 0.74)
    static let violet = Color(red: 0.62, green: 0.48, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.8, blue: 0.25)
    static let unplayed = Color.white.opacity(0.22)
}

/// Says on screen that the audio is synthesized demo audio.
struct DemoAudioBadge: View {
    var compact = false

    var body: some View {
        Label(compact ? "Demo audio" : "Generated demo audio", systemImage: "sparkles")
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(DemoPalette.yellow)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(DemoPalette.yellow.opacity(0.16), in: Capsule())
            .accessibilityLabel(Text("Generated demo audio, synthesized by the example's script"))
    }
}
