import Foundation

/// Formats playback times the way audio players show them: "0:07", "1:05", "1:02:03".
public enum WaveformTime {
    /// Whole seconds, rounded down; negative and non-finite times show as "0:00".
    public static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let paddedSeconds = secs < 10 ? "0\(secs)" : "\(secs)"
        if hours > 0 {
            let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
            return "\(hours):\(paddedMinutes):\(paddedSeconds)"
        }
        return "\(minutes):\(paddedSeconds)"
    }

    /// The time left, with a leading minus sign: "-0:23".
    public static func remaining(_ current: TimeInterval, of duration: TimeInterval) -> String {
        let left = duration.isFinite && current.isFinite ? max(0, duration - current) : 0
        return "-" + format(left)
    }
}
