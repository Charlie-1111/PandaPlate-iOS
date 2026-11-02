import SwiftUI
import UIKit

/// Plays `frame-00.png`, `frame-01.png`, and later frames from `PipLife/Frames/<resourceName>`.
struct PipFrameSequenceView: View {
    let resourceName: String
    let stillAssetName: String
    var size: CGFloat = 200
    var height: CGFloat? = nil
    var frameDuration: TimeInterval = 1.0 / 6.0
    var accessibilityLabel: String = "Pip"
    var playsOnce = false
    var onOneShotFinished: (() -> Void)?
    var usesResourceFrames = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frameIndex = 0
    @State private var frames: [UIImage] = []
    @State private var hasAppeared = false
    @State private var isOnScreen = false
    @State private var isScrollVisible = true
    @State private var didFinishOneShot = false

    private var isPlaybackActive: Bool {
        guard hasAppeared, scenePhase == .active else { return false }
        if #available(iOS 18.0, *) {
            return isScrollVisible
        }
        return isOnScreen
    }

    private var shouldAnimateFrames: Bool {
        isPlaybackActive && !reduceMotion && usesResourceFrames && frames.count > 1
    }

    private var playbackTaskKey: String {
        "\(resourceName)|\(usesResourceFrames)|\(playsOnce)|\(isPlaybackActive)|\(reduceMotion)|\(frames.count)|\(frameDuration)"
    }

    private var framePeriod: TimeInterval {
        min(max(frameDuration, 0.08), 1.0)
    }

    private var oneShotDuration: TimeInterval {
        if usesResourceFrames && frames.count > 1 {
            return max(0.4, framePeriod * Double(frames.count - 1))
        }
        return resourceName.localizedCaseInsensitiveContains("celebrate") ? 0.92 : 0.70
    }

    @ViewBuilder
    private var renderedImage: some View {
        if shouldAnimateFrames {
            Image(uiImage: frames[frameIndex % frames.count])
                .resizable()
                .scaledToFit()
        } else {
            Image(stillAssetName)
                .resizable()
                .scaledToFit()
        }
    }

    private var screenVisibilityProbe: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateScreenVisibility(proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { _, frame in
                    updateScreenVisibility(frame)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                renderedImage
                    .onScrollVisibilityChange(threshold: 0.05) { visible in
                        isScrollVisible = visible
                    }
            } else {
                renderedImage
            }
        }
        .frame(width: size, height: height ?? size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .onAppear {
            hasAppeared = true
            isScrollVisible = true
            loadFramesIfNeeded()
        }
        .onDisappear { hasAppeared = false }
        .onChange(of: resourceName) { _, _ in
            resetAndLoadFrames()
        }
        .onChange(of: usesResourceFrames) { _, _ in
            resetAndLoadFrames()
        }
        .onChange(of: playsOnce) { _, _ in
            frameIndex = 0
            didFinishOneShot = false
        }
        .task(id: playbackTaskKey) {
            await runPlaybackTask()
        }
        .background(screenVisibilityProbe)
    }

    private func resetAndLoadFrames() {
        frames = []
        frameIndex = 0
        didFinishOneShot = false
        loadFramesIfNeeded()
    }

    private func loadFramesIfNeeded() {
        guard usesResourceFrames, frames.isEmpty,
              !resourceName.isEmpty,
              !resourceName.contains("/"),
              !resourceName.contains("\\") else { return }

        let directory = "PipLife/Frames/\(resourceName)"
        var loaded: [UIImage] = []
        for index in 0..<32 {
            let frameName = String(format: "frame-%02d", index)
            guard let url = Bundle.main.url(
                forResource: frameName,
                withExtension: "png",
                subdirectory: directory
            ), let image = UIImage(contentsOfFile: url.path) else {
                break
            }
            loaded.append(image)
        }
        frames = loaded.count > 1 ? loaded : []
        frameIndex = 0
    }

    private func updateScreenVisibility(_ frame: CGRect) {
        let bounds = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .coordinateSpace.bounds
        isOnScreen = bounds.map { frame.intersects($0) } ?? true
    }

    @MainActor
    private func runPlaybackTask() async {
        guard isPlaybackActive else { return }

        if playsOnce {
            guard !didFinishOneShot else { return }
            guard shouldAnimateFrames else {
                do {
                    try await Task.sleep(for: .seconds(oneShotDuration))
                } catch {
                    return
                }
                guard isPlaybackActive, !Task.isCancelled else { return }
                didFinishOneShot = true
                onOneShotFinished?()
                return
            }

            while frameIndex < frames.count - 1 && shouldAnimateFrames && !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(framePeriod))
                } catch {
                    return
                }
                guard shouldAnimateFrames, !Task.isCancelled else { return }
                frameIndex += 1
            }
            guard frameIndex == frames.count - 1, isPlaybackActive, !Task.isCancelled else { return }
            didFinishOneShot = true
            onOneShotFinished?()
            return
        }

        guard shouldAnimateFrames else { return }
        while shouldAnimateFrames && !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(framePeriod))
            } catch {
                return
            }
            guard shouldAnimateFrames, !Task.isCancelled, !frames.isEmpty else { return }
            frameIndex = (frameIndex + 1) % frames.count
        }
    }
}
