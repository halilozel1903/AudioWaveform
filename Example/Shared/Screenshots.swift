import Foundation
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene shows the generated demo audio bundled with the app, with the player paused at a fixed position
/// (42 %). No scene uses the microphone, and the recorder is not part of the screenshots.
enum ScreenshotScene: String {
    /// iPhone and Apple Watch: the player with the scrubbable waveform.
    case player
    /// iPhone: the same track in every waveform style.
    case styles

    static var requested: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready` into the app
    /// container, once `isReady` is true and the frame had time to settle. Nothing animates in a screenshot scene,
    /// so the frame is final by then.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
