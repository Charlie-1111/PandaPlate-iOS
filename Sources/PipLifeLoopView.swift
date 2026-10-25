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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frameIndex = 0
    @State private var frames: [UIImage] = []
    @State private var frameDuration: TimeInterval = 1.0 / 6.0

    private var shouldAnimate: Bool {
        !reduceMotion && scenePhase == .active && frames.count > 1
    }

    var body: some View {
        Group {
            if reduceMotion || frames.isEmpty {
                Image(stillAssetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(uiImage: frames[frameIndex % frames.count])
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: height ?? size)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .onAppear { loadIfNeeded() }
        .onChange(of: resourceName) { _, _ in
            frames = []
            frameIndex = 0
            loadIfNeeded()
        }
        .task(id: shouldAnimate) {
            guard shouldAnimate else {
                frameIndex = 0
                return
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    return
                }
                guard shouldAnimate, !Task.isCancelled, !frames.isEmpty else { return }
                frameIndex = (frameIndex + 1) % frames.count
            }
        }
    }

    private func loadIfNeeded() {
        guard frames.isEmpty else { return }
        guard let url = Self.locateResource(resourceName) else { return }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return }

        var loaded: [UIImage] = []
        var totalDuration: TimeInterval = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            loaded.append(UIImage(cgImage: cg))
            totalDuration += Self.frameDelay(source: source, index: i)
        }
        guard !loaded.isEmpty else { return }
        frames = loaded
        if count > 0 {
            let avg = totalDuration / Double(count)
            // Spec: ~6fps (167ms). Clamp wild metadata.
            frameDuration = min(max(avg > 0 ? avg : 1.0 / 6.0, 0.08), 0.35)
        }
        frameIndex = 0
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
