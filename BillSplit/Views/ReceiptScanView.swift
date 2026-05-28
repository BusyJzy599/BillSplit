import SwiftUI
import PhotosUI

struct ReceiptScanView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: Int
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var isScanning = false
    @State private var receiptItems: [ReceiptItem] = []
    @State private var errorMessage: String?
    @State private var navigateToConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding()
                }

                if isScanning {
                    ProgressView("识别中...")
                        .padding()
                } else if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.viewfinder")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.tint)

                        Text("拍摄收据照片进行识别")
                            .font(.headline)

                        HStack(spacing: 16) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("拍照", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label("相册", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 40)
                    }
                }

                Spacer()
            }
            .navigationTitle("收据识别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $capturedImage, onCapture: {
                    showCamera = false
                    scanImage()
                })
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(image: $capturedImage, onPick: {
                    showPhotoPicker = false
                    scanImage()
                })
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                ReceiptConfirmationView(
                    items: receiptItems,
                    groupId: groupId,
                    memberIds: memberIds,
                    userNames: userNames,
                    currentUserId: currentUserId,
                    payerId: currentUserId,
                    onDismiss: { dismiss() }
                )
            }
        }
    }

    @State private var aiItems: [AIExtractedItem] = []
    @State private var useAI = true

    private func scanImage() {
        guard let image = capturedImage else { return }
        isScanning = true; errorMessage = nil

        Task {
            do {
                // Step 1: Vision OCR
                let rawItems = try await OCRService.shared.recognizeText(from: image)
                guard !rawItems.isEmpty else {
                    await MainActor.run {
                        isScanning = false
                        errorMessage = "No text found. Try a clearer photo."
                    }
                    return
                }

                // Step 2: AI extraction (if configured)
                if AIService.shared.isConfigured && useAI {
                    let rawText = rawItems.map { $0.description }.joined(separator: "\n")
                    do {
                        let extracted = try await AIService.shared.extractItems(from: rawText)
                        await MainActor.run {
                            isScanning = false
                            aiItems = extracted
                            receiptItems = extracted.map {
                                ReceiptItem(description: $0.description, amount: $0.amount, isShared: $0.isShared)
                            }
                            navigateToConfirm = true
                        }
                    } catch {
                        // AI failed, fall back to raw OCR
                        await MainActor.run {
                            isScanning = false
                            receiptItems = rawItems
                            navigateToConfirm = true
                        }
                    }
                } else {
                    // No AI, use raw OCR
                    await MainActor.run {
                        isScanning = false
                        receiptItems = rawItems
                        navigateToConfirm = true
                    }
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    errorMessage = "Scan failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Camera View (UIKit bridge)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onCapture: () -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.onCapture()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Picker

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onPick: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                picker.dismiss(animated: true)
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                    picker.dismiss(animated: true)
                    self.parent.onPick()
                }
            }
        }
    }
}
