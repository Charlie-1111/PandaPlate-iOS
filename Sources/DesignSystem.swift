import SwiftUI

enum PPColor {
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let card = Color(red: 1.00, green: 0.99, blue: 0.96)
    static let coral = Color(red: 0.94, green: 0.35, blue: 0.27)
    static let coralInk = Color(red: 0.62, green: 0.16, blue: 0.12)
    static let ink = Color(red: 0.18, green: 0.12, blue: 0.10)
    static let muted = Color(red: 0.49, green: 0.43, blue: 0.39)
    static let line = Color(red: 0.89, green: 0.83, blue: 0.75)
    static let mint = Color(red: 0.84, green: 0.91, blue: 0.83)
    static let lavender = Color(red: 0.88, green: 0.84, blue: 0.93)
    static let peach = Color(red: 1.00, green: 0.88, blue: 0.79)
}

/// BitePal-parity chrome for onboarding beats Charlie wants visually copied.
/// Pip art stays PP_*; backgrounds/CTAs/selection follow BitePal frames.
enum BitePalColor {
    /// Mint green sampled from pip-peek-swipe.gif intro video (RGB 184,227,202).
    /// Source of truth for meet-pet / reveal / Pip rise backgrounds.
    static let introVideoGreen = Color(red: 184.0 / 255.0, green: 227.0 / 255.0, blue: 202.0 / 255.0) // #B8E3CA
    /// Meet-pet / reveal soft mint (aligned to intro video green).
    static let mintScreen = Color(red: 184.0 / 255.0, green: 227.0 / 255.0, blue: 202.0 / 255.0) // #B8E3CA
    /// Question-flow light grey (#E9E8EE / #F2F2F7-ish).
    static let questionBG = Color(red: 0.914, green: 0.910, blue: 0.933) // #E9E8EE
    static let tipPill = Color(red: 0.875, green: 0.871, blue: 0.894) // #DFDFE4
    /// Pastel pink small-steps screen.
    static let pinkScreen = Color(red: 0.984, green: 0.839, blue: 0.835) // #FBD6D5
    static let starSalmon = Color(red: 0.980, green: 0.510, blue: 0.431) // #FA8270
    /// Eating-habits mint room wall.
    static let kitchenMint = Color(red: 0.882, green: 0.945, blue: 0.878) // #E1F1E0
    static let kitchenFloor = Color(red: 0.996, green: 0.929, blue: 0.800) // #FEEDCC
    /// Account light blue tint.
    static let accountBlue = Color(red: 0.843, green: 0.882, blue: 0.988) // #D7E1FC
    /// Black pill CTAs.
    static let ctaBlack = Color(red: 0.094, green: 0.094, blue: 0.094) // #181818
    /// Selection accent green.
    static let selectGreen = Color(red: 0.282, green: 0.659, blue: 0.314) // #48A850
    static let selectFill = Color(red: 0.706, green: 0.894, blue: 0.745) // #B4E4BE
    static let whiteCard = Color.white
    static let titleGrey = Color(red: 0.55, green: 0.55, blue: 0.58)
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
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 17)
            .background(PPColor.coral, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

struct PPCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PPColor.line.opacity(0.55), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2))
            .tracking(1.3)
            .foregroundStyle(PPColor.muted)
    }
}

struct ProgressSegments: View {
    let current: Int
    let count: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? PPColor.coral : PPColor.line.opacity(0.65))
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

struct ChoiceRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? PPColor.coralInk : PPColor.ink)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? PPColor.peach : PPColor.cream, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.ink)
                    Text(subtitle).font(.system(size: 12, weight: .regular, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.muted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PPColor.coralInk).font(.system(size: 20))
                }
            }
            .padding(13)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? PPColor.coral : PPColor.line.opacity(0.65), lineWidth: isSelected ? 1.5 : 1))
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
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .title3)).foregroundStyle(PPColor.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }
        }
    }
}
