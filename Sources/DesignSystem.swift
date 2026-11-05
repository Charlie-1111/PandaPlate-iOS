import SwiftUI
import UIKit

enum PPColor {
    // Wave 1: warm cream stage, orange CTAs/FAB/focus, forest secondary only.
    static let forest = Color(red: 0.184, green: 0.416, blue: 0.310)       // #2F6A4F secondary
    static let forestDeep = Color(red: 0.145, green: 0.298, blue: 0.231)   // #254C3B secondary
    static let accentCoral = Color(red: 0.769, green: 0.361, blue: 0.243) // #C45C3E CTAs/FAB/focus
    static let cream = Color(red: 0.965, green: 0.953, blue: 0.918)       // #F6F3EA stage
    static let card = Color(red: 0.998, green: 0.992, blue: 0.973)         // #FFFEF8 cards
    static let softBlue = Color(red: 0.902, green: 0.937, blue: 0.957)     // #E6EFF4 demoted helper
    static let sage = Color(red: 0.886, green: 0.925, blue: 0.875)         // #E2ECDC demoted helper
    static let ink = Color(red: 0.125, green: 0.204, blue: 0.157)         // #203429
    static let muted = Color(red: 0.345, green: 0.408, blue: 0.365)       // #58685D
    static let line = Color(red: 0.839, green: 0.875, blue: 0.831)        // #D6DFD4
    static let selectedWash = Color(red: 0.965, green: 0.890, blue: 0.855) // warm wash from accent

    // Semantic aliases — CTAs resolve to orange; forest stays explicit secondary.
    static let coral = accentCoral
    static let coralInk = accentCoral
    static let mint = sage
    static let lavender = softBlue
    static let peach = Color(red: 0.980, green: 0.925, blue: 0.890) // warm peach, not powder-blue
    static let primary = accentCoral
    static let primaryInk = accentCoral
    static let border = line
}

enum PPSpacing {
    /// Wave 4 vertical rhythm: 4 / 8 / 12 / 16 / 24.
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let pageInset: CGFloat = 20
    static let cardInset: CGFloat = 16
    static let cardInsetRoomy: CGFloat = 20
    static let buttonVertical: CGFloat = 17
    static let progressThickness: CGFloat = 5
    static let tabContentTop: CGFloat = 12
    static let stackGap: CGFloat = 12
}

enum PPRadius {
    static let icon: CGFloat = 14
    static let choice: CGFloat = 18
    static let card: CGFloat = 22
    static let sheet: CGFloat = 26
}

enum PPType {
    /// Wave 4 scale: largeTitle / title2 / headline / body / callout / caption2.
    /// Prefer these over one-off fixed sizes so Dynamic Type stays honest.
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .heavy, design: .rounded, relativeTo: style)
    }

    static func largeTitle(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .largeTitle)
    }

    static func title2(_ size: CGFloat = 22, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .title2)
    }

    static func title(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .rounded, relativeTo: .title3)
    }

    static func headline(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .headline)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .body)
    }

    static func callout(_ size: CGFloat = 14, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .callout)
    }

    static func caption(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .caption)
    }

    static func caption2(_ size: CGFloat = 11, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .caption2)
    }

    /// Soft Show-Up / quota chips — Dynamic Type via .subheadline, not fixed pt-only.
    static func chip(_ size: CGFloat = 13, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .subheadline)
    }
}

enum PPIcon {
    static let tabPointSize: CGFloat = 22
    static let fabPlusPointSize: CGFloat = 24
    static let fabHit: CGFloat = 56
}

enum PPElevation {
    /// Warm orange-black ~8% — not cool slate iOS default.
    static let warmShadow = Color(red: 0.35, green: 0.18, blue: 0.12).opacity(0.08)
    static let warmRadius: CGFloat = 12
    static let warmY: CGFloat = 4
    static let pressedSettle: CGFloat = 2
}

/// Compatibility chrome names. Wave 1 demotes BitePal mint / powder-blue from primary stage.
/// Pip original assets stay unchanged; CTAs resolve through PPColor.accentCoral.
enum BitePalColor {
    /// Kept for Pip intro video frame samples only — not primary chrome.
    static let introVideoGreen = Color(red: 184.0 / 255.0, green: 227.0 / 255.0, blue: 202.0 / 255.0) // #B8E3CA
    /// Meet-pet / reveal: cream stage (mint demoted from primary chrome).
    static let mintScreen = PPColor.cream
    /// Warm paper question surface; tip pill uses sage, not powder-blue.
    static let questionBG = PPColor.cream
    static let tipPill = PPColor.sage
    /// Soft cream helper field (powder-blue demoted).
    static let pinkScreen = PPColor.cream
    static let starSalmon = PPColor.accentCoral
    /// Eating-habits room wall — cream stage, sage secondary only.
    static let kitchenMint = PPColor.cream
    static let kitchenFloor = PPColor.cream
    /// Account tint — cream, not powder-blue.
    static let accountBlue = PPColor.cream
    /// CTAs use orange accent (Wave 1), not forest twin.
    static let ctaBlack = PPColor.accentCoral
    /// Selection uses orange focus; forest remains available as PPColor.forest.
    static let selectGreen = PPColor.accentCoral
    static let selectFill = PPColor.selectedWash
    static let whiteCard = PPColor.card
    static let titleGrey = PPColor.muted
    // Rainbow bands (small-steps)
    static let rainbowMint = Color(red: 0.671, green: 0.914, blue: 0.851) // #ABE9D9
    static let rainbowYellow = Color(red: 0.996, green: 0.941, blue: 0.698) // #FEF0B2
    static let rainbowBlue = Color(red: 0.627, green: 0.839, blue: 0.996) // #A0D6FE
    static let rainbowGreen = Color(red: 0.412, green: 0.761, blue: 0.565) // #69C290
}



extension Font {
    /// PandaPlate display uses Avenir Next Heavy (condensed BitePal twin demoted).
    /// System faces only — no licensed webfont.
    static func system(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) -> Font {
        let face: String
        switch weight {
        case .black, .heavy:
            face = "AvenirNext-Heavy"
        case .bold: face = "AvenirNext-Bold"
        case .semibold: face = "AvenirNext-DemiBold"
        case .medium: face = "AvenirNext-Medium"
        default: face = "AvenirNext-Regular"
        }
        return .custom(face, size: size, relativeTo: textStyle)
    }

    /// Explicit display face — non-condensed to differentiate from BitePal chrome.
    static func ppDisplay(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("AvenirNext-Heavy", size: size, relativeTo: textStyle)
    }
}

struct PipMascot: View {
    var size: CGFloat = 120
    var assetName: String = "Pip"
    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Pip, the PandaPlate red panda coach")
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String = "arrow.right"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                Text(title).font(PPType.body(17, weight: .bold))
                Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.vertical, PPSpacing.buttonVertical)
            .frame(minHeight: 52)
            .background(PPColor.primary, in: Capsule())
            .shadow(color: PPColor.primaryInk.opacity(0.15), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

struct PPCard<Content: View>: View {
    var padding: CGFloat = PPSpacing.cardInset
    /// Primary plates / Soft Show-Up / scan result use elevation; nested rows can pass false.
    var elevated: Bool = true
    var cornerRadius: CGFloat = PPRadius.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ppWarmCardChrome(cornerRadius: cornerRadius, elevated: elevated)
    }
}

/// Shared warm soft card elevation on cream (Wave 4).
struct PPWarmCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PPColor.border.opacity(0.7), lineWidth: 1)
            )
            .shadow(
                color: elevated ? PPElevation.warmShadow : .clear,
                radius: elevated ? PPElevation.warmRadius : 0,
                y: elevated ? PPElevation.warmY : 0
            )
    }
}

extension View {
    func ppWarmCardChrome(cornerRadius: CGFloat = PPRadius.card, elevated: Bool = true) -> some View {
        modifier(PPWarmCardModifier(cornerRadius: cornerRadius, elevated: elevated))
    }

}

enum PPMotion {
    /// Tab content: short fade+slide; Reduce Motion → opacity only.
    static func tabContentTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 6)),
            removal: .opacity.combined(with: .offset(y: -4))
        )
    }
}

/// FAB press: soft scale 0.96 + light haptic; Reduce Motion → opacity flash only.
struct PPFABPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.72 : (configuration.isPressed ? 0.96 : 1))
            .offset(y: configuration.isPressed && !reduceMotion ? PPElevation.pressedSettle : 0)
            .animation(
                reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.18, dampingFraction: 0.78),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, !reduceMotion else { return }
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
    }
}

/// Soft empty coach: Pip + Soft show-up line + single orange CTA. Never hungry/sad.
struct PPSoftEmptyCoach: View {
    let message: String
    var title: String = "Soft show-up"
    var ctaTitle: String = "Log a plate"
    var ctaSymbol: String = "plus.circle.fill"
    var action: (() -> Void)? = nil

    var body: some View {
        PPCard(padding: PPSpacing.large) {
            VStack(alignment: .leading, spacing: PPSpacing.medium) {
                HStack(alignment: .top, spacing: PPSpacing.medium) {
                    PipMascot(size: 44)
                        .accessibilityLabel("Pip, calm coach")
                    VStack(alignment: .leading, spacing: PPSpacing.xSmall) {
                        Text(title)
                            .font(PPType.caption(12, weight: .bold))
                            .foregroundStyle(PPColor.accentCoral)
                        Text(message)
                            .font(PPType.callout(14, weight: .medium))
                            .foregroundStyle(PPColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let action {
                    Button(action: action) {
                        Label(ctaTitle, systemImage: ctaSymbol)
                            .font(PPType.body(15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(PPColor.accentCoral, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ctaTitle)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(PPType.caption(10, weight: .bold))
            .tracking(1.3)
            .foregroundStyle(PPColor.muted)
    }
}

struct ProgressSegments: View {
    let current: Int
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? PPColor.primary : PPColor.line.opacity(0.65))
                    .frame(height: PPSpacing.progressThickness)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: current)
    }
}

struct ChoiceRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(PPType.body(18, weight: .semibold))
                    .foregroundStyle(isSelected ? PPColor.primaryInk : PPColor.ink)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? PPColor.selectedWash : PPColor.cream, in: RoundedRectangle(cornerRadius: PPRadius.icon, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(PPType.body(15, weight: .bold)).foregroundStyle(PPColor.ink)
                    Text(subtitle).font(PPType.caption(12, weight: .regular)).foregroundStyle(PPColor.muted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PPColor.coralInk).font(.system(size: 20))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(PPSpacing.medium)
            .frame(minHeight: 68)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: PPRadius.choice, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PPRadius.choice, style: .continuous).stroke(isSelected ? PPColor.primary : PPColor.line.opacity(0.75), lineWidth: isSelected ? 1.5 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SectionTitle: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(PPType.title()).foregroundStyle(PPColor.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(PPType.caption(12, weight: .semibold))
                    .foregroundStyle(PPColor.primaryInk)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
        }
    }
}
