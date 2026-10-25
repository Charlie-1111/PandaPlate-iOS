import SwiftUI
import UIKit

/// Bubbles welcome’s “hide status bar” request up to `PandaPlateApp` / the hosting controller.
struct PandaPlateStatusBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// Reinforces `.statusBarHidden` under UIHostingController (Simulator often keeps battery/Wi‑Fi visible otherwise).
struct PandaPlateStatusBarHiddenEnforcer: UIViewControllerRepresentable {
    var hidden: Bool

    func makeUIViewController(context: Context) -> PandaPlateStatusBarHostController {
        PandaPlateStatusBarHostController(hidden: hidden)
    }

    func updateUIViewController(_ controller: PandaPlateStatusBarHostController, context: Context) {
        controller.apply(hidden: hidden)
    }
}

final class PandaPlateStatusBarHostController: UIViewController {
    private var statusBarHidden: Bool

    init(hidden: Bool) {
        self.statusBarHidden = hidden
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        v.isHidden = true
        view = v
    }

    override var prefersStatusBarHidden: Bool { statusBarHidden }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        propagateStatusBarUpdate()
    }

    func apply(hidden: Bool) {
        statusBarHidden = hidden
        propagateStatusBarUpdate()
    }

    private func propagateStatusBarUpdate() {
        setNeedsStatusBarAppearanceUpdate()
        var walker: UIViewController? = parent
        while let current = walker {
            current.setNeedsStatusBarAppearanceUpdate()
            walker = current.parent
        }
        view.window?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
    }
}

extension View {
    /// Hide the system status bar on welcome; restore after leaving. Preference + representable + SwiftUI modifier.
    func pandaPlateStatusBarHidden(_ hidden: Bool) -> some View {
        self
            .statusBarHidden(hidden)
            .background(PandaPlateStatusBarHiddenEnforcer(hidden: hidden).frame(width: 0, height: 0))
            .preference(key: PandaPlateStatusBarHiddenPreferenceKey.self, value: hidden)
    }
}
