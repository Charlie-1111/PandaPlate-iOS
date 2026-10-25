import SwiftUI
import UIKit

struct PandaPlateWelcomeMotion: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var isOnScreen = false

    private var shouldAnimate: Bool {
        isVisible && isOnScreen && scenePhase == .active && !reduceMotion
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PPColor.mint.opacity(0.65))
            Image("PP_LeafToken")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .offset(x: shouldAnimate ? -110 : -104, y: shouldAnimate ? -85 : -90)
                .rotationEffect(.degrees(shouldAnimate ? -14 : -4))
                .accessibilityHidden(true)
            Image(systemName: "sparkle")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PPColor.coralInk.opacity(0.82))
                .offset(x: shouldAnimate ? 112 : 106, y: shouldAnimate ? -74 : -83)
                .accessibilityHidden(true)
            PipMascot(size: 218, assetName: "PP_PipWelcome")
                .scaleEffect(shouldAnimate ? 1.025 : 1)
                .rotationEffect(.degrees(shouldAnimate ? 1.5 : 0))
                .accessibilityLabel("Pip waves hello")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(shouldAnimate ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : nil, value: shouldAnimate)
        .background(screenVisibilityProbe)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: scenePhase) { _, phase in isVisible = phase == .active }
        .onChange(of: reduceMotion) { _, reduced in isVisible = !reduced && scenePhase == .active }
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
        let screen = UIScreen.main.bounds
        isOnScreen = frame.maxX > 0 && frame.minX < screen.maxX && frame.maxY > 0 && frame.minY < screen.maxY
    }
}

struct PipReactionBeat: View {
    let assetNames: [String]
    let label: String
    var size: CGFloat = 76

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var isOnScreen = false
    @State private var frameIndex = 0

    private var shouldAnimate: Bool {
        isVisible && isOnScreen && scenePhase == .active && !reduceMotion && assetNames.count > 1
    }

    var body: some View {
        Image(assetNames.indices.contains(frameIndex) ? assetNames[frameIndex] : assetNames.first ?? "PP_PipWelcome")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
            .animation(shouldAnimate ? .easeInOut(duration: 0.28) : nil, value: frameIndex)
            .background(screenVisibilityProbe)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onChange(of: scenePhase) { _, phase in isVisible = phase == .active }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { frameIndex = 0 }
                isVisible = !reduced && scenePhase == .active
            }
            .task(id: shouldAnimate) {
                guard shouldAnimate else { frameIndex = 0; return }
                frameIndex = 0
                for nextIndex in assetNames.indices.dropFirst() {
                    do {
                        try await Task.sleep(for: .milliseconds(520))
                        guard shouldAnimate, !Task.isCancelled else { return }
                        frameIndex = nextIndex
                    } catch {
                        return
                    }
                }
            }
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
        let screen = UIScreen.main.bounds
        isOnScreen = frame.maxX > 0 && frame.minX < screen.maxX && frame.maxY > 0 && frame.minY < screen.maxY
    }
}
