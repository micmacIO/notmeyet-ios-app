import AVFoundation
import SwiftUI

struct LoopingVideoBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let forcePoster: Bool

    init(forcePoster: Bool = false) {
        self.forcePoster = forcePoster
    }

    var body: some View {
        Group {
            if usesStaticPoster {
                Image("WelcomePoster")
                    .resizable()
                    .scaledToFill()
            } else if let url = Bundle.main.url(forResource: "welcome-loop", withExtension: "mp4", subdirectory: "Resources")
                ?? Bundle.main.url(forResource: "welcome-loop", withExtension: "mp4") {
                LoopingPlayerView(url: url, isPlaying: scenePhase == .active)
            } else {
                Image("WelcomePoster")
                    .resizable()
                    .scaledToFill()
            }
        }
        .accessibilityHidden(true)
    }

    private var usesStaticPoster: Bool {
        if forcePoster || reduceMotion { return true }
        #if DEBUG
        return DebugUITestPresentation.selected(in: ProcessInfo.processInfo.arguments) == .screen01
        #else
        return false
        #endif
    }
}

private struct LoopingPlayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        isPlaying ? view.play() : view.pause()
    }

    static func dismantleUIView(_ view: PlayerLayerView, coordinator: Void) {
        view.pause()
    }
}

private final class PlayerLayerView: UIView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func configure(url: URL) {
        player.isMuted = true
        player.actionAtItemEnd = .none
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func play() { player.play() }
    func pause() { player.pause() }
}
