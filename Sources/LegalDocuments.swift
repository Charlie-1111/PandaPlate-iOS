import SwiftUI

/// In-app Terms of Use + Privacy Notice. Hosted Terms + Privacy are live on GitHub Pages.
/// ASC: paste privacyPolicyURL / termsOfUseURL into App Privacy / App Information after live 200.
enum PandaPlateLegal {
    static let supportEmail = "lisbon-oondn8@bot.cue.im"
    /// Hosted Privacy Policy (GitHub Pages HTTP 200 verified 2026-11-02).
    static let privacyPolicyURL: URL? = URL(string: "https://charlie-1111.github.io/PandaPlate-iOS/privacy.html")
    /// Hosted Terms of Use (GitHub Pages HTTP 200 verified 2026-11-06).
    static let termsOfUseURL: URL? = URL(string: "https://charlie-1111.github.io/PandaPlate-iOS/terms.html")

    enum Document: String, Identifiable {
        case termsOfUse
        case privacyNotice

        var id: String { rawValue }

        var title: String {
            switch self {
            case .termsOfUse: return "Terms of Use"
            case .privacyNotice: return "Privacy Notice"
            }
        }
    }

    static let termsOfUseBody: String = """
    Last updated: 6 November 2026 (Asia/Hong_Kong)

    Welcome to PandaPlate. These Terms of Use (“Terms”) explain how you may use this app. By tapping Get started or continuing past the welcome screen, you agree to these Terms and our Privacy Notice.

    1. Who this app is for
    PandaPlate is for people aged 13 and older. We do not knowingly collect information from children under 13. If you are under 18, some estimate screens (for example weight-date projections) may be limited or skipped for honesty and safety.

    2. What PandaPlate is (and isn’t)
    PandaPlate is a gentle food-logging and companion app. It is not medical advice, not a diagnosis tool, and not a calorie-prescription service. BMI and similar figures, when shown, are informational only from numbers you enter.

    3. Your account
    Finishing setup may require Sign in with Apple so your session can stay with you. You are responsible for the account you use. Do not use someone else’s credentials.

    4. Free and Premium
    Free includes manual logging, water, workouts, fasting tools, and a limited number of live Food Scan recognitions per day as offered in the build. Premium is optional and sold through Apple StoreKit only when subscription products are configured. Prices and renewal terms must come from the App Store purchase sheet. Manage or cancel subscriptions in Apple ID subscription settings.

    5. Camera, photos, and Health
    Camera access is requested only when you choose to take a photo for a meal log. Apple Health is read only if you tap Connect; we do not write to Health in this version. You can skip Health.

    6. Food Scan
    Live food recognition uses an owner-hosted HTTPS proxy when you choose Food Scan and give fresh consent for that upload. Selecting a photo for a manual note alone does not send the image. Barcode lookup is not offered as a production service in this version. Results are editable estimates, not health advice. Do not scan images of other people without permission.

    7. Acceptable use
    Don’t misuse the app, attempt to break scan quotas unfairly, harass others through shared exports, or use PandaPlate for anything illegal. Soft Show-Up and Pip reactions are supportive — not a grading system.

    8. Session data
    In this version, meals, photos, water, and preferences are primarily held in device memory for the session and may reset when the app closes. Cloud sync is not yet available. See the Privacy Notice.

    9. Changes
    We may update these Terms. Continued use after an in-app update means you accept the revised Terms shown here.

    10. Contact
    Questions about these Terms: email \(supportEmail). We’ll receive your message at this address.
    """

    static let privacyNoticeBody: String = """
    Last updated: 31 October 2026 (Asia/Hong_Kong)

    This Privacy Notice explains what PandaPlate handles on your device and what may leave the device when you use optional features. We do not sell your personal data.

    1. Age
    PandaPlate is for users 13+. We do not knowingly collect data from children under 13. Age you enter in onboarding (13–100) is used for setup personalization and honesty gates (for example under-18 projection limits).

    2. What stays on device (session-local)
    In the current build, meal logs, photos you attach, water entries, workout picks, fasting notes, Soft Show-Up answers, Pip preferences, and most onboarding answers are kept in app memory / local session storage and typically reset when the app closes. They are not uploaded to a PandaPlate “account cloud” in this build.

    3. Sign-in
    If you use Sign in with Apple, Apple provides an identifier (and sometimes an email) so we can recognize you for setup completion. We store those identifiers in the onboarding draft / local prefs for this session. We do not get your password.

    4. Camera and photo library
    Used when you open Food Scan (system camera or photo library) to choose one still image for a meal. Images stay on device unless you continue with Food Scan (below).

    5. Apple Health
    If you tap Connect, we may read steps, active energy, exercise time, and workouts to show today’s movement and optionally help log workouts. We do not write to Health in this version. You can skip Connect.

    6. Food Scan (optional; consent each upload)
    When you use Food Scan and consent to a live recognition request, PandaPlate may send the still meal photo you chose to an owner-hosted HTTPS proxy. Selecting a photo for a manual note alone does not send the image. The app asks for fresh consent before each upload. The current proxy may send the image to DeepSeek for vision analysis and use USDA FoodData Central to look up nutrients from food names or identifiers (USDA does not receive your photo). DeepSeek may process data under its own policy; processing or storage could involve China, and we cannot confirm retention or whether inputs are used for model training. Results are uncertain estimates; you can edit them before saving. Do not include other people or personal details. Barcode lookup is not a production service in this version.

    7. Purchases
    Premium purchases and restores go through Apple StoreKit. Apple processes payment; we receive entitlement status, not your full card number.

    8. Analytics / ads / sale of data
    This build does not include third-party ad networks or a data-broker pipeline. We do not sell personal data. If analytics are added later, Charlie will update this Notice before shipping that change.

    9. Exports
    If you use Export this session, a CSV (or similar) is created for you to share via the system share sheet — you choose the destination.

    10. Your choices
    Skip Health, skip reminders, continue with Free, dismiss Premium, and review answers before finishing setup. Uninstalling the app removes local session data for this build.

    11. Contact
    Privacy questions: email \(supportEmail). We’ll receive your message at this address.
    """
}

/// Reusable sheet host for Terms / Privacy.
struct PandaPlateLegalDocumentSheet: View {
    let document: PandaPlateLegal.Document
    @Environment(\.dismiss) private var dismiss

    private var bodyText: String {
        switch document {
        case .termsOfUse: return PandaPlateLegal.termsOfUseBody
        case .privacyNotice: return PandaPlateLegal.privacyNoticeBody
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(bodyText)
                        .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if document == .termsOfUse, let url = PandaPlateLegal.termsOfUseURL {
                        Link(destination: url) {
                            Label("Open hosted Terms of Use", systemImage: "safari")
                                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .body))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .accessibilityHint("Opens the Terms of Use in Safari")
                    }

                    if document == .privacyNotice, let url = PandaPlateLegal.privacyPolicyURL {
                        Link(destination: url) {
                            Label("Open hosted Privacy Policy", systemImage: "safari")
                                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .body))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .accessibilityHint("Opens the Privacy Policy in Safari")
                    }

                    Link(destination: URL(string: "mailto:\(PandaPlateLegal.supportEmail)")!) {
                        Label("Email support · \(PandaPlateLegal.supportEmail)", systemImage: "envelope.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.coralInk)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityHint("Opens a new email to PandaPlate support")
                }
                .padding(20)
            }
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(PPColor.coralInk)
                }
            }
        }
    }
}

/// Compact tappable Terms + Privacy links row (welcome + profile).
struct PandaPlateLegalLinksRow: View {
    var preface: String = "By continuing you’re accepting our"
    var style: Style = .welcome
    @Binding var presentedDocument: PandaPlateLegal.Document?
    @Environment(\.openURL) private var openURL

    enum Style {
        case welcome
        case profile
    }

    var body: some View {
        VStack(alignment: style == .welcome ? .center : .leading, spacing: 6) {
            if style == .welcome {
                Text(preface)
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    legalButton("Terms of Use", .termsOfUse)
                    Text("and")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                    legalButton("Privacy Notice", .privacyNotice)
                }
            } else {
                Text("Legal")
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                HStack(spacing: 16) {
                    legalButton("Terms of Use", .termsOfUse)
                    legalButton("Privacy Notice", .privacyNotice)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func legalButton(_ title: String, _ doc: PandaPlateLegal.Document) -> some View {
        Button {
            if doc == .termsOfUse, let url = PandaPlateLegal.termsOfUseURL {
                openURL(url)
            } else if doc == .privacyNotice, let url = PandaPlateLegal.privacyPolicyURL {
                openURL(url)
            } else {
                presentedDocument = doc
            }
        } label: {
            Text(title)
                .font(.system(size: style == .welcome ? 12 : 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(style == .welcome ? BitePalColor.selectGreen : PPColor.coralInk)
                .underline(style == .welcome, color: BitePalColor.selectGreen.opacity(0.85))
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Larger hit target so welcome footer taps aren’t eaten by overlays / Spacers.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .zIndex(2)
        .accessibilityLabel(title)
        .accessibilityHint(
            doc == .termsOfUse && PandaPlateLegal.termsOfUseURL != nil
                ? "Opens hosted Terms of Use in Safari"
                : doc == .privacyNotice && PandaPlateLegal.privacyPolicyURL != nil
                    ? "Opens hosted Privacy Policy in Safari"
                    : "Opens \(title) in this app"
        )
        .accessibilityAddTraits(.isButton)
    }
}
