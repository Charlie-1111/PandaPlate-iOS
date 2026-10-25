import SwiftUI

/// Full-screen, finite Pip reveal: peek → open box → leap → happy landing.
/// Uses only PandaPlate-owned art and pauses/settles when hidden or Reduce Motion is enabled.
struct PandaPlateMidflowRevealArtwork: View {
    var animationEnabled = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var phase = 3

    private var shouldAnimate: Bool {
        animationEnabled && isVisible && scenePhase == .active && !reduceMotion
    }

    private var phaseDescription: String {
        guard shouldAnimate else { return "Static Pip greeting pose" }
        switch phase {
        case 0: return "Pip peeks from a closed box"
        case 1: return "The box opens and Pip peeks out"
        case 2: return "Pip jumps up and out of the box"
        default: return "Pip lands and settles into a happy pose"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Match pip-peek-swipe.gif mint (#B8E3CA) — not cream PP_RevealBackground.
                BitePalColor.introVideoGreen
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)

                if reduceMotion || !animationEnabled || scenePhase != .active {
                    Image("PP_PipWelcome")
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geometry.size.width * 0.68, 260))
                        .accessibilityHidden(true)
                } else {
                    animatedPip(boxWidth: min(geometry.size.width * 0.62, 242), boxHeight: min(geometry.size.height * 0.28, 172))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .offset(y: phase == 2 ? -24 : (phase == 3 ? -4 : 0))
                        .scaleEffect(phase == 2 ? 1.07 : 1)
                        .animation(.spring(response: 0.52, dampingFraction: 0.72), value: phase)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("pandaplate-midflow-pip-reveal")
            .accessibilityLabel("Pip’s animated reveal")
            .accessibilityValue(phaseDescription)
            .accessibilityAddTraits(.isImage)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: scenePhase) { _, phase in
            isVisible = phase == .active
            if phase != .active { self.phase = 3 }
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
                    try await Task.sleep(for: .milliseconds(780))
                    guard shouldAnimate, !Task.isCancelled else { return }
                    phase = nextPhase
                } catch {
                    return
                }
            }
        }
    }

    @ViewBuilder
    private func animatedPip(boxWidth: CGFloat, boxHeight: CGFloat) -> some View {
        let pipSize = min(boxWidth * 0.88, 222)
        ZStack(alignment: .bottom) {
            switch phase {
            case 0:
                Image("PP_PipPeek")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pipSize * 0.62, height: pipSize * 0.62)
                    .offset(y: -boxHeight * 0.46)
                closedBox(width: boxWidth, height: boxHeight)
            case 1:
                Image("PP_PipReveal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pipSize * 0.86, height: pipSize * 0.86)
                    .offset(y: -boxHeight * 0.49)
                    .transition(.scale(scale: 0.86).combined(with: .opacity))
                openBox(width: boxWidth, height: boxHeight)
            case 2:
                Image("PP_PipCelebrate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pipSize, height: pipSize)
                    .offset(y: -boxHeight * 0.90)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                openBox(width: boxWidth, height: boxHeight)
            default:
                Image("PP_PipWelcome")
                    .resizable()
                    .scaledToFit()
                    .frame(width: pipSize * 0.91, height: pipSize * 0.91)
                    .offset(y: -boxHeight * 0.68)
                    .transition(.opacity)
                openBox(width: boxWidth, height: boxHeight)
            }
        }
        .frame(width: boxWidth * 1.35, height: max(boxHeight * 1.85, pipSize * 1.28), alignment: .bottom)
    }

    private func closedBox(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.83, green: 0.45, blue: 0.27))
                .frame(width: width * 0.88, height: height * 0.68)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PPColor.coralInk.opacity(0.5), lineWidth: 3)
                        .frame(width: width * 0.88, height: height * 0.68)
                }
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.96, green: 0.65, blue: 0.38))
                .frame(width: width * 0.94, height: height * 0.16)
                .offset(y: -height * 0.54)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 0.99, green: 0.82, blue: 0.60))
                .frame(width: width * 0.08, height: height * 0.68)
                .offset(y: -height * 0.34)
        }
        .frame(width: width, height: height)
    }

    private func openBox(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.83, green: 0.45, blue: 0.27))
                .frame(width: width * 0.84, height: height * 0.48)
                .offset(y: -height * 0.03)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PPColor.coralInk.opacity(0.5), lineWidth: 3)
                        .frame(width: width * 0.84, height: height * 0.48)
                        .offset(y: -height * 0.03)
                }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.98, green: 0.70, blue: 0.45))
                .frame(width: width * 0.45, height: height * 0.10)
                .rotationEffect(.degrees(-34))
                .offset(x: -width * 0.34, y: -height * 0.40)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.98, green: 0.70, blue: 0.45))
                .frame(width: width * 0.45, height: height * 0.10)
                .rotationEffect(.degrees(34))
                .offset(x: width * 0.34, y: -height * 0.40)
        }
        .frame(width: width, height: height)
    }
}
