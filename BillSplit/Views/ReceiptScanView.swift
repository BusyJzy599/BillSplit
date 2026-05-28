import SwiftUI
import PhotosUI

enum ScanState { case idle, scanning, confirming }

struct ReceiptScanView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: Int; let memberIds: [String]; let userNames: [String: String]; let currentUserId: String

    @State private var state: ScanState = .idle
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var errorMessage: String?
    @State private var items: [ReceiptItem] = []
    @State private var payerId: String
    @State private var isSubmitting = false

    init(groupId: Int, memberIds: [String], userNames: [String: String], currentUserId: String) {
        self.groupId = groupId; self.memberIds = memberIds; self.userNames = userNames; self.currentUserId = currentUserId
        _payerId = State(initialValue: currentUserId)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .idle:
                    idleView
                case .scanning:
                    scanningView
                case .confirming:
                    confirmingView
                }
            }
            .navigationTitle(state == .confirming ? "Confirm Items" : "Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .onChange(of: state) { _, v in
            if v == .scanning { startScan() }
            if v == .confirming || v == .idle { showCamera = false; showPhotoPicker = false }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                CameraView(image: $capturedImage, onCapture: { state = .scanning }).ignoresSafeArea()
                if state == .scanning {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(.white).scaleEffect(1.5)
                        Text("AI analyzing receipt...").foregroundColor(.white).font(.headline)
                        if let img = capturedImage {
                            Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).cornerRadius(12).padding(.horizontal, 40)
                        }
                        if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption).padding() }
                    }
                }
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(image: $capturedImage, onPick: { state = .scanning })
        }
    }

    // MARK: - Idle

    var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "doc.text.viewfinder").resizable().frame(width: 80, height: 80).foregroundStyle(.tint)
            Text("Take a photo of your receipt").font(.headline)
            HStack(spacing: 16) {
                Button { showCamera = true } label: { Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                Button { showPhotoPicker = true } label: { Label("Album", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
            }.padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Scanning

    var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            if let image = capturedImage {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 250).cornerRadius(12).padding(.horizontal)
            }
            ProgressView("AI analyzing receipt...").padding()
            if let err = errorMessage { Text(err).foregroundColor(.red).font(.caption) }
            Spacer()
        }
    }

    // MARK: - Confirming

    var confirmingView: some View {
        Form {
            Section("Items (tap to toggle shared)") {
                let sharedItems = items.filter { $0.isShared }
                let personalItems = items.filter { !$0.isShared }

                if !sharedItems.isEmpty {
                    ForEach(sharedItems) { item in itemRow(item) }
                }
                if !personalItems.isEmpty {
                    Section("Personal Items") { ForEach(personalItems) { item in itemRow(item) } }
                }
                if items.isEmpty { Text("No items found").foregroundColor(.secondary) }
            }

            Section("Payer") {
                Picker("Payer", selection: $payerId) {
                    ForEach(memberIds, id: \.self) { id in Text(userNames[id] ?? "...").tag(id) }
                }
            }

            if isSubmitting {
                HStack { Spacer(); ProgressView("Creating bills..."); Spacer() }
            } else {
                Section {
                    Button("Generate Bills (\(items.count) items)") { submitBills() }.disabled(items.isEmpty)
                }
            }

            Section { Button("Rescan") { state = .idle; items = []; errorMessage = nil } }
        }
    }

    @ViewBuilder
    func itemRow(_ item: ReceiptItem) -> some View {
        HStack {
            Button {
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    var updated = items[idx]; updated.isShared.toggle(); items[idx] = updated
                }
            } label: {
                Image(systemName: item.isShared ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isShared ? .accentColor : .secondary)
            }.buttonStyle(.plain)
            VStack(alignment: .leading) {
                Text(item.description.isEmpty ? "Unnamed" : item.description).font(.subheadline)
                if let amt = item.amount { Text(String(format: "$%.2f", amt)).font(.caption).foregroundColor(.secondary) }
            }
            Spacer()
            if !item.isShared, let uid = item.assignedToUserId { Text(userNames[uid] ?? "").font(.caption).foregroundColor(.accentColor) }
            Button {
                items.removeAll { $0.id == item.id }
            } label: { Image(systemName: "trash").foregroundColor(.red).font(.caption) }
        }
    }

    // MARK: - Scan

    func startScan() {
        guard capturedImage != nil else { return }
        state = .scanning; errorMessage = nil

        Task {
            do {
                let rawItems = try await OCRService.shared.recognizeText(from: capturedImage!)

                // Try AI extraction
                if AIService.shared.isConfigured {
                    let rawText = rawItems.map { item in
                        if let amt = item.amount { return "\(item.description) $\(amt)" }
                        return item.description
                    }.joined(separator: "\n")
                    do {
                        let extracted = try await AIService.shared.extractItems(from: rawText)
                        if !extracted.isEmpty {
                            await MainActor.run {
                                items = extracted.map { ReceiptItem(description: $0.description, amount: $0.amount, isShared: $0.isShared) }
                                state = .confirming
                            }
                            return
                        }
                    } catch {
                        print("AI extraction failed, falling back to OCR: \(error)")
                    }
                }

                // Fall back to raw OCR
                await MainActor.run {
                    items = rawItems
                    state = rawItems.isEmpty ? .idle : .confirming
                    if rawItems.isEmpty { errorMessage = "No text found. Try a clearer photo." }
                }
            } catch {
                await MainActor.run { errorMessage = "Scan failed: \(error.localizedDescription)"; state = .idle }
            }
        }
    }

    func submitBills() {
        isSubmitting = true
        let validItems = items.filter { ($0.amount ?? 0) > 0 }
        let sharedItems = validItems.filter { $0.isShared }
        let personalItems = validItems.filter { !$0.isShared }

        Task {
            do {
                if !sharedItems.isEmpty {
                    let total = sharedItems.reduce(0.0) { $0 + ($1.amount ?? 0) }
                    try await BillService.shared.createBill(groupId: groupId, payerId: payerId, amount: total,
                        description: sharedItems.map { $0.description }.joined(separator: ", "), participantIds: memberIds)
                }
                for item in personalItems {
                    try await BillService.shared.createBill(groupId: groupId, payerId: payerId, amount: item.amount ?? 0,
                        description: item.description, participantIds: [item.assignedToUserId ?? memberIds.first ?? ""])
                }
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run { isSubmitting = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Camera / PhotoPicker (unchanged)
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?; let onCapture: () -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ ui: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let p: CameraView; init(_ p: CameraView) { self.p = p }
        func imagePickerController(_ pk: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { p.image = img }; p.onCapture()
        }
        func imagePickerControllerDidCancel(_ pk: UIImagePickerController) { p.onCapture() }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?; let onPick: () -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var c = PHPickerConfiguration(); c.filter = .images; c.selectionLimit = 1
        let p = PHPickerViewController(configuration: c); p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ ui: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let p: PhotoPicker; init(_ p: PhotoPicker) { self.p = p }
        func picker(_ pk: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let r = results.first else { pk.dismiss(animated: true); return }
            r.itemProvider.loadObject(ofClass: UIImage.self) { img, _ in
                DispatchQueue.main.async { self.p.image = img as? UIImage; pk.dismiss(animated: true); self.p.onPick() }
            }
        }
    }
}
