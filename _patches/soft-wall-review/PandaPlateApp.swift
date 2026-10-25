import SwiftUI

@main
struct PandaPlateApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

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
        }
    }
}
