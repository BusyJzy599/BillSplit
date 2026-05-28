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
    @State private var editingItem: ReceiptItem?
    @State private var editItemDesc = ""
    @State private var editItemAmt = ""
    @State private var selectedIndices: Set<Int> = [0]

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

    var selectedItems: [ReceiptItem] { items.enumerated().filter { selectedIndices.contains($0.offset) }.map(\.element) }
    var selectedTotal: Double { selectedItems.reduce(0) { $0 + ($1.amount ?? 0) } }

    var confirmingView: some View {
        Form {
            Section {
                HStack { Text("Items").font(.headline); Spacer(); Text(String(format: "$%.2f", selectedTotal)).font(.headline).foregroundColor(.accentColor) }
                Text("\(selectedIndices.count)/\(items.count) selected · Tap to toggle").font(.caption).foregroundColor(.secondary)
            }

            Section {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                HStack {
                    Button {
                        if selectedIndices.contains(idx) { selectedIndices.remove(idx) }
                        else { selectedIndices.insert(idx) }
                    } label: {
                        Image(systemName: selectedIndices.contains(idx) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedIndices.contains(idx) ? .accentColor : .secondary)
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.description.isEmpty ? "Unnamed" : item.description).font(.subheadline)
                        if let amt = item.amount, amt > 0 {
                            Text(String(format: "$%.2f", amt)).font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        editingItem = item; editItemDesc = item.description
                        editItemAmt = item.amount.map { String(format: "%.2f", $0) } ?? ""
                    } label: { Image(systemName: "pencil").font(.caption).foregroundColor(.secondary) }
                }
            }.onDelete { idxSet in
                for i in idxSet.sorted(by: >) { items.remove(at: i); selectedIndices.remove(i) }
            }
            }

            Section {
                HStack {
                    Text("Paid by").font(.subheadline)
                    Spacer()
                    Picker("", selection: $payerId) {
                        ForEach(memberIds, id: \.self) { id in Text(userNames[id] ?? "...").tag(id) }
                    }
                }
            }

            if isSubmitting {
                HStack { Spacer(); ProgressView("Creating bills..."); Spacer() }
            } else {
                Section {
                    Button("Generate \(selectedIndices.count) Bills ($\(String(format: "%.2f", selectedTotal)))") { submitBills() }
                        .disabled(selectedIndices.isEmpty).frame(maxWidth: .infinity)
                }
            }

            Section { Button("Rescan") { state = .idle; items = []; selectedIndices = [0]; errorMessage = nil }.foregroundColor(.secondary) }
        }
        .sheet(item: $editingItem) { _ in
            NavigationStack {
                Form {
                    TextField("Name", text: $editItemDesc)
                    TextField("Amount", text: $editItemAmt).keyboardType(.decimalPad)
                }
                .navigationTitle("Edit Item").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingItem = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let idx = items.firstIndex(where: { $0.id == editingItem?.id }) {
                                items[idx].description = editItemDesc
                                items[idx].amount = Double(editItemAmt)
                            }
                            editingItem = nil
                        }
                    }
                }
            }.presentationDetents([.height(250)])
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
                                // Show all extracted items, default select first only
                                items = extracted.enumerated().map { i, e in
                                    ReceiptItem(description: e.description, amount: e.amount, isShared: e.isShared)
                                }
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
        let validItems = selectedItems.filter { ($0.amount ?? 0) > 0 }
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
