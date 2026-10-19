import AudioWaveform
import AudioWaveformUI
import SwiftUI

@main
struct WavesWatchApp: App {
    @State private var model: DemoModel

    init() {
        _model = State(initialValue: DemoModel(scene: ScreenshotScene.requested))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(scene: ScreenshotScene.requested)
                .environment(model)
                .tint(DemoPalette.played)
        }
    }
}

/// Vertically paged screens: the player and the level meter. A screenshot launch shows the player on its own.
struct WatchRootView: View {
    let scene: ScreenshotScene?

    @Environment(DemoModel.self) private var model

    var body: some View {
        Group {
            if scene != nil {
                WatchPlayerView()
            } else {
                TabView {
                    WatchPlayerView()
                    WatchRecordView()
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .task {
            if model.phase != .loaded {
                await model.load()
            }
        }
        .signalsScreenshotReady(scene, when: model.phase == .loaded)
    }
}

/// One watch page: a navigation title next to the system clock (so content never sits under the clock), a tinted
/// background, and the content once the demo audio is loaded.
struct WatchPage<Content: View>: View {
    let title: String
    let content: Content

    @Environment(DemoModel.self) private var model

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loaded:
                    ScrollView {
                        content
                    }
                case .loading:
                    ProgressView()
                case let .failed(message):
                    ScrollView {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.slash")
                                .font(.title2)
                            Text(message)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await model.load() }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .containerBackground(DemoPalette.played.opacity(0.28).gradient, for: .navigation)
        }
    }
}
