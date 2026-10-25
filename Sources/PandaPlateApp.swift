import SwiftUI
import GoogleSignIn

@main
struct PandaPlateApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    /// Driven by onboarding welcome via PreferenceKey — hides battery/Wi‑Fi/signal there only.
    @State private var hideStatusBar = false

    init() {
        Self.configureGoogleSignInIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if store.finishedOnboarding {
                        MainShellView()
                    } else {
                        PandaPlateCategorizedOnboardingFlow { draft in
                            store.applyOnboardingDraft(draft)
                        }
                    }
                }
                .environmentObject(store)
                .preferredColorScheme(.light)
                .privacySensitive()

                if scenePhase != .active {
                    PPColor.cream.ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 10) {
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(PPColor.coralInk)
                                Text("PandaPlate is paused")
                                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .headline))
                                    .foregroundStyle(PPColor.ink)
                            }
                        }
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onAppear {
                Self.configureGoogleSignInIfNeeded()
                // Presence means they opened the app — never require a meal or Pip ritual to avoid a no-show.
                SoftShowUpStore.shared.markSeen()
                PipHeartsStore.shared.refreshDecayIfNeeded(showUpDays: SoftShowUpStore.shared.days)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                SoftShowUpStore.shared.markSeen()
                PipHeartsStore.shared.refreshDecayIfNeeded(showUpDays: SoftShowUpStore.shared.days)
            }
            .onPreferenceChange(PandaPlateStatusBarHiddenPreferenceKey.self) { hideStatusBar = $0 }
            .statusBarHidden(hideStatusBar)
        }
    }

    /// Reads `GIDClientID` from Info.plist / Bundle so Charlie can paste one value later without code edits.
    private static func configureGoogleSignInIfNeeded() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty,
              !clientID.contains("REPLACE_WITH_GOOGLE") else {
            // Placeholder still in place — leave unconfigured; UI shows a clear message on tap.
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
