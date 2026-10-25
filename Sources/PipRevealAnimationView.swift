import SwiftUI

struct PipRevealAnimationView: View {
    var animationEnabled = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var phase = 3

    private var shouldAnimate: Bool {
        animationEnabled && isVisible && scenePhase == .active && !reduceMotion
    }

    private var phaseDescription: String {
        guard animationEnabled, scenePhase == .active, !reduceMotion else {
            return "Static Pip greeting pose; animation is skipped or paused"
        }
        return switch phase {
        case 0: "Closed box; Pip peeks over the edge"
        case 1: "The box opens and Pip peeks out"
        case 2: "Pip jumps up and out of the box"
        default: "Pip lands and settles into a happy greeting"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Match pip-peek-swipe.gif mint (#B8E3CA) — not cream PP_RevealBackground.
                BitePalColor.introVideoGreen
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if reduceMotion || !animationEnabled || scenePhase != .active {
                    Image("PP_PipWelcome")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width * 0.72, 250))
                        .offset(y: -12)
                        .accessibilityHidden(true)
                } else {
                    revealArtwork
                        .frame(width: min(geometry.size.width * 0.84, 290), height: min(geometry.size.height * 0.82, 340))
                        .offset(y: phase == 2 ? -28 : (phase == 3 ? -8 : 0))
                        .scaleEffect(phase == 2 ? 1.06 : 1)
                        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: phase)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("pip-reveal-animation")
            .accessibilityLabel("Pip’s animated reveal")
            .accessibilityValue(phaseDescription)
            .accessibilityAddTraits(.isImage)
        }
        .frame(height: 338)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: scenePhase) { _, phase in
            isVisible = phase == .active
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { phase = 3 }
            isVisible = !reduced && scenePhase == .active
        }
        .task(id: shouldAnimate) {
            guard shouldAnimate else { phase = 3; return }
            phase = 0
            for nextPhase in 1...3 {
                do {
                    try await Task.sleep(for: .milliseconds(420))
                    guard shouldAnimate, !Task.isCancelled else { return }
                    phase = nextPhase
                } catch {
                    return
                }
            }
        }
    }

    @ViewBuilder
    private var revealArtwork: some View {
        switch phase {
        case 0:
            closedBoxWithPeek
        case 1:
            Image("PP_PipReveal")
                .resizable()
                .scaledToFit()
                .transition(.scale(scale: 0.86).combined(with: .opacity))
        case 2:
            jumpingOutOfBox
                .transition(.scale(scale: 0.70).combined(with: .opacity))
        default:
            settledByOpenBox
                .transition(.opacity)
        }
    }

    private var closedBoxWithPeek: some View {
        ZStack(alignment: .bottom) {
            Image("PP_PipPeek")
                .resizable()
                .scaledToFit()
                .frame(width: 126, height: 126)
                .offset(y: -66)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.83, green: 0.45, blue: 0.27))
                .frame(width: 210, height: 136)
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(red: 0.99, green: 0.77, blue: 0.53))
                        .frame(width: 18, height: 136)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.96, green: 0.65, blue: 0.38))
                        .frame(width: 224, height: 26)
                        .overlay {
                            Rectangle()
                                .fill(Color(red: 0.99, green: 0.82, blue: 0.60))
                                .frame(width: 18)
                        }
                        .offset(y: -12)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PPColor.coralInk.opacity(0.45), lineWidth: 3)
                }

            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PPColor.coralInk)
                .offset(x: 118, y: -126)
        }
        .frame(width: 250, height: 220)
        .offset(y: -8)
        .transition(.opacity)
    }

    private var openBoxBase: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.83, green: 0.45, blue: 0.27))
                .frame(width: 184, height: 92)
                .offset(y: 24)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PPColor.coralInk.opacity(0.5), lineWidth: 3)
                        .frame(width: 184, height: 92)
                        .offset(y: 24)
                }

            Ellipse()
                .fill(PPColor.coralInk.opacity(0.84))
                .frame(width: 150, height: 27)
                .offset(y: -24)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.98, green: 0.70, blue: 0.45))
                .frame(width: 91, height: 17)
                .rotationEffect(.degrees(-34))
                .offset(x: -79, y: -51)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.98, green: 0.70, blue: 0.45))
                .frame(width: 91, height: 17)
                .rotationEffect(.degrees(34))
                .offset(x: 79, y: -51)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.99, green: 0.77, blue: 0.53))
                .frame(width: 184, height: 18)
                .rotationEffect(.degrees(-8))
                .offset(y: -5)
        }
        .frame(width: 220, height: 146)
        .accessibilityHidden(true)
    }

    private var jumpingOutOfBox: some View {
        ZStack(alignment: .bottom) {
            openBoxBase
            Image("PP_PipCelebrate")
                .resizable()
                .scaledToFit()
                .frame(width: 178, height: 178)
                .offset(y: -65)
        }
        .frame(width: 250, height: 292)
    }

    private var settledByOpenBox: some View {
        ZStack(alignment: .bottom) {
            openBoxBase
            Image("PP_PipWelcome")
                .resizable()
                .scaledToFit()
                .frame(width: 158, height: 158)
                .offset(y: -65)
        }
        .frame(width: 250, height: 292)
    }
}
