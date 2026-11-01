import SwiftUI
import UIKit

struct CameraPhotoPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIViewController {
        // Gallery selection uses PhotosPicker. This picker is camera-only so the
        // binary does not open the photo library through UIImagePickerController.
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let unavailable = UnavailableCameraController()
            unavailable.onAppear = context.coordinator.onCancel
            return unavailable
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        fileprivate let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
            else { onCancel() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

private final class UnavailableCameraController: UIViewController {
    var onAppear: (() -> Void)?
    private var didNotify = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didNotify else { return }
        didNotify = true
        onAppear?()
    }
}
