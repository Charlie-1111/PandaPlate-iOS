import SwiftUI
import ImageIO
import UIKit

/// Plays a bundled APNG (or multi-frame PNG) via CGImageSource.
/// Reduce Motion / missing resource → still Image fallback.
struct PipLifeLoopView: View {
    /// Resource basename in the app bundle (e.g. "PP_PipLife_Wave") — looks for .apng then .png.
    let resourceName: String
    /// Catalog imageset name used when Reduce Motion is on or the loop cannot load.
    let stillAssetName: String
    var size: CGFloat = 200
    /// When set, frame height uses this instead of `size` (for tall GIFs).
    var height: CGFloat? = nil
    var accessibilityLabel: String = "Pip"
    /// When true, plays the loaded frames once then calls `onOneShotFinished`.
    var playsOnce = false
    var onOneShotFinished: (() -> Void)?
    /// Costume-specific stills must stay visible instead of being replaced by a base-costume loop.
    var usesResourceFrames = true
    /// When the primary PNG is single-frame, alternate these bundled poses for a gentle idle loop.
    var companionFrameResourceNames: [String] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frameIndex = 0
    @State private var frames: [UIImage] = []
    @State private var frameDuration: TimeInterval = 1.0 / 6.0
    @State private var hasDistinctFrames = false
    @State private var oneShotProgress: TimeInterval = 0
    @State private var isVisible = false
    @State private var isOnScreen = false
    @State private var isScrollVisible = true

    private var isPlaybackActive: Bool {
        isVisible && isOnScreen && isScrollVisible && scenePhase == .active
    }

    private var shouldAnimateResourceFrames: Bool {
        isPlaybackActive && !reduceMotion && usesResourceFrames && hasDistinctFrames && frames.count > 1
    }

    private var animationTaskKey: String {
        "\(resourceName)|\(playsOnce)|\(isPlaybackActive)|\(reduceMotion)|\(shouldAnimateResourceFrames)"
    }

    private var oneShotDuration: TimeInterval {
        if shouldAnimateResourceFrames {
            return max(0.4, frameDuration * Double(max(frames.count - 1, 1)))
        }
        return resourceName.localizedCaseInsensitiveContains("celebrate") ? 0.92 : 0.70
    }

    @ViewBuilder
    private var renderedImage: some View {
        if shouldAnimateResourceFrames && !frames.isEmpty {
            Image(uiImage: frames[frameIndex % frames.count])
                .resizable()
                .scaledToFit()
        } else {
            Image(stillAssetName)
                .resizable()
                .scaledToFit()
        }
    }

    private var motionContent: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaybackActive || reduceMotion || playsOnce)) { timeline in
            let pose = motionPose(at: timeline.date)
            renderedImage
                .frame(width: size, height: height ?? size)
                .scaleEffect(pose.scale, anchor: .bottom)
                .rotationEffect(.degrees(pose.rotationDegrees), anchor: .bottom)
                .offset(y: pose.offsetY)
        }
    }

    @ViewBuilder
    var body: some View {
        if usesResourceFrames {
            PipFrameSequenceView(
                resourceName: resourceName,
                stillAssetName: stillAssetName,
                size: size,
                height: height,
                frameDuration: 1.0 / 6.0,
                accessibilityLabel: accessibilityLabel,
                playsOnce: playsOnce,
                onOneShotFinished: onOneShotFinished
            )
        } else {
            proceduralBody
        }
    }

    private var proceduralBody: some View {
        Group {
            if #available(iOS 18.0, *) {
                motionContent
                    .onScrollVisibilityChange(threshold: 0.05) { visible in
                        isScrollVisible = visible
                    }
            } else {
                motionContent
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .onAppear {
            isVisible = true
            loadIfNeeded()
        }
        .onDisappear { isVisible = false }
        .onChange(of: resourceName) { _, _ in
            resetFrames()
            loadIfNeeded()
        }
        .onChange(of: companionFrameResourceNames) { _, _ in
            resetFrames()
            loadIfNeeded()
        }
        .task(id: animationTaskKey) {
            await runMotionTask()
        }
        .background(screenVisibilityProbe)
    }

    private func resetFrames() {
        frames = []
        frameIndex = 0
        hasDistinctFrames = false
        oneShotProgress = 0
    }

    private func loadIfNeeded() {
        guard usesResourceFrames, frames.isEmpty else { return }
        guard let url = Self.locateResource(resourceName) else { return }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return }

        var loaded: [UIImage] = []
        var firstFrameRaster: Data?
        var hasDistinctRaster = false
        var totalDuration: TimeInterval = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            loaded.append(UIImage(cgImage: cg))
            if let raster = cg.dataProvider?.data as Data? {
                if let firstFrameRaster {
                    hasDistinctRaster = hasDistinctRaster || raster != firstFrameRaster
                } else {
                    firstFrameRaster = raster
                }
            }
            totalDuration += Self.frameDelay(source: source, index: i)
        }
        if !hasDistinctRaster, !companionFrameResourceNames.isEmpty {
            var companions: [UIImage] = []
            for name in companionFrameResourceNames {
                guard let companionURL = Self.locateResource(name),
                      let companionSource = CGImageSourceCreateWithURL(companionURL as CFURL, nil),
                      let cg = CGImageSourceCreateImageAtIndex(companionSource, 0, nil) else { continue }
                companions.append(UIImage(cgImage: cg))
            }
            if companions.count >= 2 {
                loaded = companions
                hasDistinctRaster = true
                totalDuration = Double(companions.count) * (1.0 / 2.5)
            }
        }
        guard !loaded.isEmpty else { return }
        hasDistinctFrames = hasDistinctRaster
        frames = hasDistinctFrames ? loaded : []
        if count > 0 || hasDistinctRaster {
            let frameCount = max(loaded.count, count)
            let avg = totalDuration / Double(max(frameCount, 1))
            frameDuration = min(max(avg > 0 ? avg : 1.0 / 2.5, 0.28), 0.55)
        }
        frameIndex = 0
    }

    private var screenVisibilityProbe: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { updateScreenVisibility(proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { _, frame in updateScreenVisibility(frame) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func updateScreenVisibility(_ frame: CGRect) {
        isOnScreen = frame.intersects(UIScreen.main.bounds)
    }

    @MainActor
    private func runMotionTask() async {
        guard isPlaybackActive else { return }
        if reduceMotion {
            if playsOnce {
                do {
                    try await Task.sleep(for: .seconds(oneShotDuration))
                } catch {
                    return
                }
                guard isPlaybackActive, !Task.isCancelled else { return }
                onOneShotFinished?()
            }
            return
        }

        if playsOnce {
            let step = 1.0 / 24.0
            while oneShotProgress < oneShotDuration && isPlaybackActive && !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(step))
                } catch {
                    return
                }
                guard isPlaybackActive, !Task.isCancelled else { return }
                oneShotProgress = min(oneShotDuration, oneShotProgress + step)
                if shouldAnimateResourceFrames {
                    frameIndex = min(Int(oneShotProgress / frameDuration), frames.count - 1)
                }
            }
            guard oneShotProgress >= oneShotDuration, isPlaybackActive, !Task.isCancelled else { return }
            onOneShotFinished?()
            return
        }

        guard shouldAnimateResourceFrames else { return }
        while isPlaybackActive && shouldAnimateResourceFrames && !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(frameDuration))
            } catch {
                return
            }
            guard isPlaybackActive, !Task.isCancelled, !frames.isEmpty else { return }
            frameIndex = (frameIndex + 1) % frames.count
        }
    }

    private func motionPose(at date: Date) -> MotionPose {
        guard isPlaybackActive, !reduceMotion else { return .still }

        if playsOnce {
            let progress = min(max(oneShotProgress / oneShotDuration, 0), 1)
            let mainHop = sin(Double.pi * progress)
            if resourceName.localizedCaseInsensitiveContains("celebrate") {
                let secondHop = max(0, sin(3 * Double.pi * progress))
                return MotionPose(
                    offsetY: CGFloat(-11 * mainHop - 4 * secondHop),
                    rotationDegrees: sin(4 * Double.pi * progress) * 2.0 * (1 - progress),
                    scale: CGFloat(1 + 0.035 * mainHop - 0.018 * secondHop)
                )
            }
            return MotionPose(
                offsetY: CGFloat(-9 * mainHop),
                rotationDegrees: sin(2 * Double.pi * progress) * 2.4 * (1 - progress),
                scale: CGFloat(1 + 0.018 * mainHop)
            )
        }

        let time = date.timeIntervalSinceReferenceDate
        let breath = sin(time * 1.35)
        let sway = sin(time * 0.72 + 0.4)
        return MotionPose(
            offsetY: CGFloat(breath * 2.1),
            rotationDegrees: sway * 1.15,
            scale: CGFloat(1 + breath * 0.009)
        )
    }

    private static func locateResource(_ name: String) -> URL? {
        // Prefer PipLife folder for png/apng loops; also accept root-bundle .gif (meet-pet swipe).
        let exts = ["gif", "png", "apng"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "PipLife") {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> TimeInterval {
        let fallback = 1.0 / 6.0
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] else {
            return fallback
        }
        let png = props[kCGImagePropertyPNGDictionary] as? [CFString: Any]
        if let d = png?[kCGImagePropertyAPNGUnclampedDelayTime] as? Double, d > 0 { return d }
        if let d = png?[kCGImagePropertyAPNGDelayTime] as? Double, d > 0 { return d }
        let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        if let d = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double, d > 0 { return d }
        if let d = gif?[kCGImagePropertyGIFDelayTime] as? Double, d > 0 { return d }
        return fallback
    }
}

private struct MotionPose {
    let offsetY: CGFloat
    let rotationDegrees: Double
    let scale: CGFloat

    static let still = MotionPose(offsetY: 0, rotationDegrees: 0, scale: 1)
}
