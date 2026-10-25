import AVFoundation
import SwiftUI
import UIKit

struct WelcomeAnimationView: View {
    var animationEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        Group {
            if reduceMotion || !animationEnabled || !isVisible || scenePhase != .active {
                PipMascot(size: 250, assetName: "PP_PipWelcome")
            } else if let url = Bundle.main.url(forResource: "red_panda_welcome_animation", withExtension: "mp4") {
                LoopingMutedVideo(url: url, shouldPlay: animationEnabled && isVisible && scenePhase == .active && !reduceMotion)
                    .accessibilityLabel("Pip waves hello")
            } else {
                PipMascot(size: 250, assetName: "PP_PipWelcome")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 310)
        .background(PPColor.mint.opacity(0.65), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

private struct LoopingMutedVideo: UIViewRepresentable {
    let url: URL
    let shouldPlay: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainer {
        let container = PlayerContainer()
        let player = AVQueuePlayer()
        player.isMuted = true
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: player, templateItem: item)
        container.playerLayer.player = player
        container.playerLayer.videoGravity = .resizeAspect
        context.coordinator.player = player
        context.coordinator.looper = looper
        if shouldPlay { player.play() } else { player.pause() }
        return container
    }

    func updateUIView(_ uiView: PlayerContainer, context: Context) {
        uiView.playerLayer.player = context.coordinator.player
        if shouldPlay {
            context.coordinator.player?.play()
        } else {
            context.coordinator.player?.pause()
        }
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }
}

final class PlayerContainer: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct MutedOneShotVideo: UIViewRepresentable {
    let url: URL
    let shouldPlay: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainer {
        let container = PlayerContainer()
        container.backgroundColor = .clear

        let item = AVPlayerItem(url: url)
        // Prefer smooth start over aggressive rate hacks (Charlie: lag/jank, not slow).
        item.preferredForwardBufferDuration = 1.0

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true

        container.playerLayer.player = player
        container.playerLayer.videoGravity = .resizeAspect
        container.playerLayer.needsDisplayOnBoundsChange = true

        let coordinator = context.coordinator
        coordinator.player = player
        coordinator.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak coordinator] _ in
            coordinator?.didFinish = true
            coordinator?.player?.pause()
        }

        coordinator.statusObservation = item.observe(\.status, options: [.new]) { [weak coordinator] observed, _ in
            guard observed.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                guard let coordinator, coordinator.wantsPlay, !coordinator.didFinish else { return }
                if coordinator.player?.rate == 0 {
                    coordinator.player?.play()
                }
            }
        }

        coordinator.wantsPlay = shouldPlay
        if shouldPlay, item.status == .readyToPlay {
            player.play()
        }
        return container
    }

    func updateUIView(_ uiView: PlayerContainer, context: Context) {
        let coordinator = context.coordinator
        guard let player = coordinator.player else { return }
        coordinator.wantsPlay = shouldPlay
        if shouldPlay && !coordinator.didFinish {
            // Only kick play when paused — never re-seek / re-rate (that causes hitching).
            if player.timeControlStatus != .playing && player.rate == 0 {
                player.play()
            }
        } else if player.rate != 0 {
            player.pause()
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainer, coordinator: Coordinator) {
        coordinator.statusObservation?.invalidate()
        coordinator.statusObservation = nil
        coordinator.player?.pause()
        coordinator.player?.replaceCurrentItem(with: nil)
        if let observer = coordinator.endObserver {
            NotificationCenter.default.removeObserver(observer)
            coordinator.endObserver = nil
        }
        uiView.playerLayer.player = nil
    }

    final class Coordinator {
        var player: AVPlayer?
        var endObserver: NSObjectProtocol?
        var statusObservation: NSKeyValueObservation?
        var didFinish = false
        var wantsPlay = false

        deinit {
            statusObservation?.invalidate()
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        }
    }
}
