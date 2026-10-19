import AudioWaveform
import AudioWaveformUI
import SwiftUI

@main
struct WavesPhoneApp: App {
    @State private var model: DemoModel

    init() {
        _model = State(initialValue: DemoModel(scene: ScreenshotScene.requested))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(scene: ScreenshotScene.requested)
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(DemoPalette.played)
        }
    }
}

/// Three tabs: the player, the styles and the recorder. A screenshot scene opens its tab.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case player
        case styles
        case record
    }

    let scene: ScreenshotScene?

    @Environment(DemoModel.self) private var model
    @State private var tab: Tab

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _tab = State(initialValue: scene == .styles ? .styles : .player)
    }

    var body: some View {
        TabView(selection: $tab) {
            PlayerScreen()
                .tabItem { Label("Player", systemImage: "play.circle") }
                .tag(Tab.player)
            StylesScreen()
                .tabItem { Label("Styles", systemImage: "waveform") }
                .tag(Tab.styles)
            RecordScreen()
                .tabItem { Label("Record", systemImage: "mic") }
                .tag(Tab.record)
        }
        .task {
            if model.phase != .loaded {
                await model.load()
            }
        }
        .signalsScreenshotReady(scene, when: model.phase == .loaded)
    }
}

/// The frame of every tab: a navigation bar with an inline title and a visible background, and the content in a
/// scroll view once the demo audio is loaded.
struct DemoScreen<Content: View>: View {
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
                        VStack(alignment: .leading, spacing: 14) {
                            content
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                case .loading:
                    ProgressView()
                        .controlSize(.large)
                case let .failed(message):
                    ContentUnavailableView {
                        Label("Demo Audio Missing", systemImage: "waveform.slash")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

/// A rounded card with a title, an optional caption and content.
struct DemoCard<Content: View>: View {
    let title: String
    let caption: String?
    let tint: Color
    let content: Content

    init(_ title: String, caption: String? = nil, tint: Color = .secondary, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 8)
                if let caption {
                    Text(caption)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
