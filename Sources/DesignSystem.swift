import SwiftUI

enum PPColor {
    // Forest + paper are the default product palette; warm coral is reserved for small accents.
    static let forest = Color(red: 0.184, green: 0.416, blue: 0.310)       // #2F6A4F
    static let forestDeep = Color(red: 0.145, green: 0.298, blue: 0.231)   // #254C3B
    static let accentCoral = Color(red: 0.835, green: 0.322, blue: 0.275) // #D45446
    static let cream = Color(red: 0.965, green: 0.953, blue: 0.918)       // #F6F3EA
    static let card = Color(red: 0.998, green: 0.992, blue: 0.973)         // #FFFEF8
    static let softBlue = Color(red: 0.902, green: 0.937, blue: 0.957)     // #E6EFF4
    static let sage = Color(red: 0.886, green: 0.925, blue: 0.875)         // #E2ECDC
    static let ink = Color(red: 0.125, green: 0.204, blue: 0.157)         // #203429
    static let muted = Color(red: 0.345, green: 0.408, blue: 0.365)       // #58685D
    static let line = Color(red: 0.839, green: 0.875, blue: 0.831)        // #D6DFD4
    static let selectedWash = Color(red: 0.882, green: 0.925, blue: 0.886) // #E1ECE2

    // Source-compatible aliases while existing screens migrate to semantic names.
    static let coral = forest
    static let coralInk = forestDeep
    static let mint = sage
    static let lavender = softBlue
    static let peach = softBlue
    static let primary = forest
    static let primaryInk = forestDeep
    static let border = line
}

enum PPSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let pageInset: CGFloat = 20
    static let cardInset: CGFloat = 18
    static let buttonVertical: CGFloat = 17
    static let progressThickness: CGFloat = 5
}

enum PPRadius {
    static let icon: CGFloat = 14
    static let choice: CGFloat = 18
    static let card: CGFloat = 22
    static let sheet: CGFloat = 26
}

enum PPType {
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .system(size: size, weight: .heavy, design: .rounded, relativeTo: style)
    }

    static func title(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .rounded, relativeTo: .title3)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .body)
    }

    static func caption(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded, relativeTo: .caption)
    }
}

/// BitePal-parity chrome for onboarding beats Charlie wants visually copied.
/// Pip art stays PP_*; backgrounds/CTAs/selection follow BitePal frames.
enum BitePalColor {
    /// Mint green sampled from pip-peek-swipe.gif intro video (RGB 184,227,202).
    /// Source of truth for meet-pet / reveal / Pip rise backgrounds.
    static let introVideoGreen = Color(red: 184.0 / 255.0, green: 227.0 / 255.0, blue: 202.0 / 255.0) // #B8E3CA
    /// Meet-pet / reveal soft mint (aligned to intro video green).
    static let mintScreen = Color(red: 184.0 / 255.0, green: 227.0 / 255.0, blue: 202.0 / 255.0) // #B8E3CA
    /// Warm paper question surface with a soft-blue helper pill.
    static let questionBG = PPColor.cream
    static let tipPill = PPColor.softBlue
    /// Soft blue replaces the old pink field; coral remains a small decorative accent only.
    static let pinkScreen = Color(red: 0.925, green: 0.949, blue: 0.965) // #ECF2F6
    static let starSalmon = PPColor.accentCoral
    /// Eating-habits mint room wall.
    static let kitchenMint = PPColor.sage
    static let kitchenFloor = PPColor.cream
    /// Account light blue tint.
    static let accountBlue = PPColor.softBlue
    /// Deep forest pill CTAs.
    static let ctaBlack = PPColor.forestDeep
    /// Selection accent green.
    static let selectGreen = PPColor.forest
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
    /// BitePal-style ultra-heavy condensed grotesk for display; body stays Avenir Next.
    /// System faces only — no licensed webfont. Prefer AvenirNextCondensed-Heavy; fall back to HelveticaNeue-CondensedBlack.
    static func system(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) -> Font {
        let face: String
        switch weight {
        case .black, .heavy:
            // Condensed display for large titles / CTAs (welcome, paywall, onboarding headlines).
            face = size >= 22 ? "AvenirNextCondensed-Heavy" : "AvenirNext-Heavy"
        case .bold: face = "AvenirNext-Bold"
        case .semibold: face = "AvenirNext-DemiBold"
        case .medium: face = "AvenirNext-Medium"
        default: face = "AvenirNext-Regular"
        }
        return .custom(face, size: size, relativeTo: textStyle)
    }

    /// Explicit condensed black for BitePal-parity display headlines.
    static func ppDisplay(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("AvenirNextCondensed-Heavy", size: size, relativeTo: textStyle)
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
            .accessibilityLabel("Pip, the PandaPlate red panda")
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
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: PPRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PPRadius.card, style: .continuous).stroke(PPColor.border.opacity(0.7), lineWidth: 1))
            .shadow(color: PPColor.forestDeep.opacity(0.05), radius: 9, y: 3)
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
