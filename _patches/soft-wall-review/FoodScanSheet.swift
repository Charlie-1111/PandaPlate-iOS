import SwiftUI
import PhotosUI
import UIKit

/// Capture tabs for §03 chrome (Photo primary; Search/Barcode stub).
private enum FoodScanCaptureMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case search = "Search"
    case barcode = "Barcode"
    var id: String { rawValue }
}

/// §03 Snap.Check.Log — camera-first chrome merged onto live consent / quota / client / cheer hooks.
struct FoodScanSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var quota = ScanQuotaStore.shared
    @ObservedObject private var premium = PremiumAccess.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Equatable {
        case camera
        case analyzing
        case result
    }

    @State private var step: Step = .camera
    @State private var captureMode: FoodScanCaptureMode = .photo
    @State private var selectedLibraryItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var imageData: Data?
    @State private var consented = false
    @State private var showConsentOverlay = false
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var showPaywall = false
    @State private var showCamera = false
    @State private var resultCandidate: FoodScanCandidate?
    @State private var resultNotice: String?
    @State private var editName = ""
    @State private var editPortion = ""
    @State private var editCalories = ""
    @State private var mealType = "Lunch"
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var showCelebrate = false
    @State private var celebrateScale: CGFloat = 0.86
    @State private var celebrateOpacity: Double = 0

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]

    private var parsedCalories: Int? {
        let value = editCalories.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let number = Int(value), (0...10_000).contains(number) else { return nil }
        return number
    }

    private var caloriesAreValid: Bool {
        let value = editCalories.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || parsedCalories != nil
    }

    private var canSaveResult: Bool {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 120 && caloriesAreValid && store.meals.count < AppStore.maximumMealsPerSession
    }

    /// AI badge only when server returned real nutrition values (never for blank/nil).
    private var hasServerNutrition: Bool {
        guard let candidate = resultCandidate else { return false }
        if candidate.calories != nil { return true }
        if let source = candidate.nutritionSource, !source.isEmpty { return true }
        return false
    }

    var body: some View {
        ZStack {
            PPColor.cream.ignoresSafeArea()

            Group {
                switch step {
                case .camera:
                    cameraPhase
                        .overlay {
                            if showConsentOverlay {
                                consentOverlay
                                    .transition(.opacity)
                            }
                        }
                case .analyzing:
                    ScanAnalyzingBeatView(reduceMotion: reduceMotion)
                case .result:
                    ScanResultCardView(
                        previewImage: previewImage,
                        dishName: $editName,
                        portionLabel: $editPortion,
                        mealType: $mealType,
                        mealTypes: mealTypes,
                        caloriesText: $editCalories,
                        caloriesAreValid: caloriesAreValid,
                        hasServerNutrition: hasServerNutrition,
                        nutritionSource: resultCandidate?.nutritionSource,
                        notice: resultNotice,
                        notes: resultCandidate?.notes,
                        fdcMatches: resultCandidate?.fdcMatches ?? [],
                        isPremium: premium.isPremium,
                        onFreeTap: { showPaywall = true },
                        canSave: canSaveResult,
                        onBack: { resetToCamera(clearConsent: false) },
                        onScanAgain: { resetToCamera(clearConsent: true) },
                        onSave: saveResult
                    )
                }
            }
            .disabled(showCelebrate)
            .opacity(showCelebrate ? 0.35 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)

            if showCelebrate {
                celebrateOverlay
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker(
                onCapture: { image in
                    showCamera = false
                    applyCapturedImage(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .onDisappear { photoLoadTask?.cancel() }
    }

    // MARK: - Camera phase (§03)

    private var cameraPhase: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(PPColor.ink)
                        .frame(width: 40, height: 40)
                        .background(PPColor.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()
                Text("Snap your meal")
                    .font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(PPColor.ink)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text(quota.quotaSummaryLine)
                .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)
                .padding(.top, 6)

            Spacer(minLength: 12)

            ScanCameraChromeView(
                previewImage: previewImage,
                guideText: "Keep the whole plate in view.",
                mode: $captureMode,
                onShutter: handleShutterTap,
                photosPickerItem: $selectedLibraryItem
            )
            .padding(.horizontal, 16)
            .onChange(of: selectedLibraryItem) { _, item in
                loadLibraryPhoto(item)
            }

            if let scanError {
                Text(scanError)
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .multilineTextAlignment(.center)
            }

            if !premium.isPremium {
                Button { showPaywall = true } label: {
                    Text("Need more scans? Unlock Premium")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }

            Text("You can review everything before saving.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Consent overlay (every scan; soft dim — camera chrome still present)

    private var consentOverlay: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Before we look at your plate")
                    .font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(PPColor.ink)
                Text("Send this photo to the local PandaPlate Server for recognition. Photo isn’t stored on our servers beyond this request. Unknown values stay blank — we never invent nutrition.")
                    .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $consented) {
                    Text("I understand and agree for this scan")
                        .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                }
                .tint(PPColor.coral)

                Button(action: confirmConsentAndScan) {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            consented ? PPColor.coralInk : PPColor.coralInk.opacity(0.4),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(!consented)

                Button("Not now") {
                    showConsentOverlay = false
                    consented = false
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(24)
        }
    }

    // MARK: - Cheer (live Celebrate path)

    private var cheerPhrase: String {
        let name = store.companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pip = name.isEmpty ? "Pip" : name
        return "\(pip) saw that — nice log."
    }

    private var celebrateOverlay: some View {
        VStack(spacing: 14) {
            PipMascot(size: 140, assetName: "PP_PipCelebrate")
                .scaleEffect(celebrateScale)
                .opacity(celebrateOpacity)
                .accessibilityLabel("Pip celebrates your log")
            Text(cheerPhrase)
                .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                .foregroundStyle(PPColor.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .opacity(celebrateOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PPColor.cream.opacity(0.96).ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cheerPhrase)
    }

    // MARK: - Actions

    private func handleShutterTap() {
        scanError = nil
        guard captureMode == .photo else {
            scanError = captureMode == .search
                ? "Search is coming — use Photo for now."
                : "Barcode is coming — use Photo for now."
            return
        }
        if previewImage == nil {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            } else {
                scanError = "Camera isn’t available here — pick a photo from the gallery."
            }
            return
        }
        beginConsentThenScan()
    }

    private func beginConsentThenScan() {
        // Honesty: consent every scan — reset so overlay always returns.
        consented = false
        showConsentOverlay = true
    }

    private func confirmConsentAndScan() {
        guard consented else { return }
        showConsentOverlay = false
        startScan()
    }

    private func startScan() {
        scanError = nil
        guard let image = previewImage else { return }
        guard consented else {
            scanError = FoodScanClient.userMessage(forServerCode: "explicit_live_consent_required", fallback: nil)
            showConsentOverlay = true
            return
        }
        guard quota.canStartLiveScan(isPremium: premium.isPremium) else {
            showPaywall = true
            scanError = "You’ve used today’s 3 free Food Scans. Unlock Premium for unlimited scans, or try again tomorrow."
            step = .camera
            return
        }

        // Honesty: clear prior candidate so analyzing never shows stale macros.
        resultCandidate = nil
        resultNotice = nil
        editName = ""
        editPortion = ""
        editCalories = ""
        isScanning = true
        step = .analyzing

        Task {
            do {
                let response = try await FoodScanClient.scan(image: image, consent: true)
                await MainActor.run {
                    isScanning = false
                    applyScanResponse(response)
                    quota.recordSuccessfulLiveScan()
                    step = .result
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    resultCandidate = nil
                    scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    step = .camera
                }
            }
        }
    }

    private func applyScanResponse(_ response: FoodScanResponse) {
        resultCandidate = response.candidate
        resultNotice = response.notice
        editName = response.candidate.foodDescription
        editPortion = response.candidate.portion ?? ""
        // Honesty: nil calories → blank editor, never "0".
        if let calories = response.candidate.calories {
            editCalories = String(calories)
        } else {
            editCalories = ""
        }
    }

    private func saveResult() {
        guard canSaveResult, !showCelebrate else { return }
        let food = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        let portion = editPortion.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [mealType, food]
        if !portion.isEmpty { parts.append(portion) }
        let name = parts.joined(separator: " · ")
        let caloriesValue: Int? = editCalories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : parsedCalories
        store.addMeal(name: name, calories: caloriesValue, imageData: imageData)
        playCelebrateThenDismiss()
    }

    private func playCelebrateThenDismiss() {
        showCelebrate = true
        celebrateScale = reduceMotion ? 1 : 0.86
        celebrateOpacity = 0
        let hold: Double = reduceMotion ? 0.85 : 1.15
        if reduceMotion {
            celebrateOpacity = 1
            celebrateScale = 1
            Task {
                try? await Task.sleep(for: .seconds(hold))
                await MainActor.run { dismiss() }
            }
        } else {
            withAnimation(.easeOut(duration: 0.35)) {
                celebrateOpacity = 1
                celebrateScale = 1.06
            }
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        celebrateScale = 1.0
                    }
                }
                try? await Task.sleep(for: .seconds(hold - 0.38))
                await MainActor.run { dismiss() }
            }
        }
    }

    private func resetToCamera(clearConsent: Bool) {
        if clearConsent {
            consented = false
        }
        showConsentOverlay = false
        resultCandidate = nil
        resultNotice = nil
        scanError = nil
        isScanning = false
        step = .camera
    }

    private func applyCapturedImage(_ image: UIImage) {
        guard let raw = image.jpegData(compressionQuality: 0.85) else {
            scanError = "Couldn’t prepare that camera photo safely."
            return
        }
        guard let reduced = BoundedPhotoLoader.jpegData(from: raw) ?? (raw.count <= 1_000_000 ? raw : nil),
              reduced.count <= 1_000_000,
              let ui = UIImage(data: reduced) else {
            scanError = "Couldn’t prepare that camera photo safely."
            return
        }
        previewImage = ui
        imageData = reduced
        resultCandidate = nil
        scanError = nil
        // After capture, prompt consent for this scan (honesty: every scan).
        beginConsentThenScan()
    }

    private func loadLibraryPhoto(_ item: PhotosPickerItem?) {
        photoLoadTask?.cancel()
        guard let item else { return }
        isScanning = false
        scanError = nil
        photoLoadTask = Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    await MainActor.run { scanError = "Couldn’t load that photo." }
                    return
                }
                guard data.count <= 12_000_000 else {
                    await MainActor.run { scanError = "That photo is too large. Choose one under 12 MB." }
                    return
                }
                guard let reduced = BoundedPhotoLoader.jpegData(from: data), reduced.count <= 1_000_000,
                      let ui = UIImage(data: reduced) else {
                    await MainActor.run { scanError = "Couldn’t prepare that photo safely." }
                    return
                }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    previewImage = ui
                    imageData = reduced
                    resultCandidate = nil
                }
            } catch {
                await MainActor.run { scanError = "Couldn’t load that photo. Try another." }
            }
        }
    }
}

// MARK: - Inlined helpers (one-file land — no project.yml churn)

private struct ScanCameraChromeView: View {
    let previewImage: UIImage?
    let guideText: String
    @Binding var mode: FoodScanCaptureMode
    let onShutter: () -> Void
    @Binding var photosPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 16) {
            viewfinder
            modeTabs
            controlsRow
        }
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PPColor.ink.opacity(0.08))
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 10) {
                            Image("PP_PipScanner")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)
                                .accessibilityHidden(true)
                            Text("Frame your plate")
                                .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                                .foregroundStyle(PPColor.muted)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(PPColor.coralInk.opacity(0.85), lineWidth: 2)
                        .padding(18)
                )

            VStack {
                Spacer()
                Text(guideText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 28)
            }
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera viewfinder. \(guideText)")
    }

    private var modeTabs: some View {
        HStack(spacing: 0) {
            ForEach(FoodScanCaptureMode.allCases) { tab in
                Button {
                    mode = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(mode == tab ? .white : PPColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            mode == tab ? PPColor.coralInk : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(PPColor.card, in: Capsule())
        .overlay(Capsule().stroke(PPColor.line.opacity(0.6), lineWidth: 1))
    }

    private var controlsRow: some View {
        HStack(spacing: 28) {
            PhotosPicker(selection: $photosPickerItem, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PPColor.ink)
                    .frame(width: 48, height: 48)
                    .background(PPColor.card, in: Circle())
            }
            .accessibilityLabel("Choose from photos")

            Button(action: onShutter) {
                ZStack {
                    Circle()
                        .strokeBorder(PPColor.coralInk, lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(PPColor.coralInk)
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shutter")

            Button {
                // Flash stub — layout match board; no-op for first land.
            } label: {
                Image(systemName: "bolt.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PPColor.muted)
                    .frame(width: 48, height: 48)
                    .background(PPColor.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Flash")
        }
        .padding(.top, 4)
    }
}

private struct ScanAnalyzingBeatView: View {
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Group {
                if reduceMotion {
                    Image("PP_PipThinking")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                } else {
                    Image("PP_PipThinking")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulse ? 1.04 : 0.96)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulse
                        )
                        .onAppear { pulse = true }
                }
            }
            .accessibilityLabel("Pip is thinking about your meal")

            Text("Looking at your plate…")
                .font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .headline))
                .foregroundStyle(PPColor.ink)

            Text("Real estimate from the Server — nothing made up while we wait.")
                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            ProgressView()
                .tint(PPColor.coralInk)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PPColor.cream.ignoresSafeArea())
    }
}

private struct ScanResultCardView: View {
    let previewImage: UIImage?
    @Binding var dishName: String
    @Binding var portionLabel: String
    @Binding var mealType: String
    let mealTypes: [String]
    @Binding var caloriesText: String
    let caloriesAreValid: Bool
    let hasServerNutrition: Bool
    let nutritionSource: String?
    let notice: String?
    let notes: String?
    let fdcMatches: [FoodScanFDCMatch]
    let isPremium: Bool
    var onFreeTap: () -> Void
    let canSave: Bool
    let onBack: () -> Void
    let onScanAgain: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    mealHeader
                    if !fdcMatches.isEmpty {
                        fdcPinRow
                    }
                    mealMeta
                    calorieBlock
                    honestyNotes
                    Text("Photo estimates can vary")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }
                .padding(18)
            }
            saveBar
        }
        .background(PPColor.cream.ignoresSafeArea())
    }

    private var fdcPinRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("USDA matches")
                .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
            ForEach(fdcMatches.prefix(3)) { match in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.description)
                            .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                            .lineLimit(2)
                        Text("FDC \(match.fdcId)")
                            .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    }
                    Spacer(minLength: 0)
                    PinUSDAFavoriteButton(
                        fdcId: match.fdcId,
                        description: match.description,
                        lastCalories: nil,
                        isPremium: isPremium,
                        onFreeTap: onFreeTap
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(12)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("Pin stores name + FDC id only. Doesn’t skip consent on the next scan.")
                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PPColor.ink)
                    .frame(width: 40, height: 40)
                    .background(PPColor.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()
            Text("Looks delicious.")
                .font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .headline))
                .foregroundStyle(PPColor.ink)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var mealHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    PPColor.peach.opacity(0.5)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                TextField("Dish name", text: $dishName)
                    .font(.system(size: 18, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(PPColor.ink)

                if hasServerNutrition {
                    Text("✨ AI estimate · Review portions")
                        .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.36, green: 0.56, blue: 0.42), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PPColor.line.opacity(0.6), lineWidth: 1)
        )
    }

    private var mealMeta: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal")
                .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mealTypes, id: \.self) { type in
                        let selected = mealType == type
                        Button { mealType = type } label: {
                            Text(type)
                                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(selected ? .white : PPColor.ink)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(selected ? PPColor.coralInk : PPColor.peach, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Portion")
                    .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                TextField("Portion, optional", text: $portionLabel)
                    .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var calorieBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("—", text: $caloriesText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 36, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(maxWidth: 140)
                Text("kcal")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(PPColor.coralInk)
            }
            if !caloriesAreValid {
                Text("Enter a whole number from 0 to 10,000, or leave blank for unknown.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.coralInk)
            }
            Text("Blank calories stay unknown and aren’t counted as zero.")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var honestyNotes: some View {
        if let nutritionSource, !nutritionSource.isEmpty {
            Text("Source: \(nutritionSource)")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
        if let notice, !notice.isEmpty {
            Text(notice)
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
        if let notes, !notes.isEmpty {
            Text(notes)
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            Button(action: onSave) {
                Text("Save to \(mealType.lowercased())")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(canSave ? PPColor.coralInk : PPColor.muted.opacity(0.45), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Button("Scan again", action: onScanAgain)
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(PPColor.cream.opacity(0.96))
    }
}
