import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 从系统相册选图。`PHPickerViewController` 是免权限的，
/// 比 `UIImagePickerController` 少一次权限弹窗。
struct ImagePicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void

        init(onPick: @escaping (Data) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            for result in results {
                // 优先要原始文件的 Data；拿不到就退回 UIImage 转 JPEG
                // （HEIC 走 image 分支会自动转成 JPEG，正好统一格式）。
                if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    result.itemProvider.loadDataRepresentation(
                        forTypeIdentifier: UTType.image.identifier) { data, _ in
                        guard let data else { return }
                        Task { @MainActor in self.onPick(data) }
                    }
                }
            }
        }
    }
}
