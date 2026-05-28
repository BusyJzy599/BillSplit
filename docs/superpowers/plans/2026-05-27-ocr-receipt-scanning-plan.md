# OCR Receipt Scanning + Local Testing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add OCR receipt scanning to bill creation flow + set up local testing environment.

**Architecture:** Apple Vision OCR (free, offline, iOS built-in) scans receipt images, parses line items with amounts, user confirms which items are shared. Shared items merge into one equal-split bill; individual items each become separate single-person bills.

**Tech Stack:** SwiftUI, Vision framework, UIKit interop (UIImagePickerController/PHPickerViewController), XcodeGen for project generation

---

## Part A: Local Testing Setup

### Task A1: Generate Xcode Project

**Files:**
- Use: `BillSplit/project.yml` (already created)
- Modify: `BillSplit/BillSplitApp.swift` — add Firebase emulator support

- [ ] **Step 1: Wait for XcodeGen install, then generate project**

```bash
cd /Users/zy/Desktop/swl/BillSplit
xcodegen generate
```

Expected: Creates `BillSplit.xcodeproj` in the BillSplit directory.

- [ ] **Step 2: Add Firebase emulator support to BillSplitApp.swift**

Read current BillSplitApp.swift, modify AppDelegate to support emulator in debug builds:

```swift
// BillSplit/BillSplitApp.swift
import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        #if DEBUG
        // Connect to Firebase local emulators
        let settings = Firestore.firestore().settings
        settings.host = "localhost:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        Firestore.firestore().settings = settings

        Auth.auth().useEmulator(withHost: "localhost", port: 9099)
        #endif

        return true
    }
}

@main
struct BillSplitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authService)
                    .environmentObject(authVM)
            }
        }
    }
}
```

- [ ] **Step 3: Create Firebase emulator config**

```bash
mkdir -p /Users/zy/Desktop/swl/firebase
```

Create `firebase/firebase.json`:

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "firestore": { "port": 8080 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

- [ ] **Step 4: Create emulator start script**

Create `firebase/start-emulators.sh`:

```bash
#!/bin/bash
cd "$(dirname "$0")/.."
firebase emulators:start --project demo-billsplit
```

```bash
chmod +x /Users/zy/Desktop/swl/firebase/start-emulators.sh
```

- [ ] **Step 5: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add XcodeGen project + Firebase emulator support"
```

---

## Part B: OCR Feature

### Task B1: ReceiptItem Model

**Files:**
- Create: `BillSplit/Models/ReceiptItem.swift`

- [ ] **Step 1: Create ReceiptItem model**

```swift
// BillSplit/Models/ReceiptItem.swift
import Foundation

struct ReceiptItem: Identifiable, Codable {
    var id = UUID()
    var description: String
    var amount: Double?
    var isShared: Bool = true
    var assignedToUserId: String? // nil = unassigned for personal items
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add BillSplit/Models/ReceiptItem.swift
git commit -m "feat: add ReceiptItem model"
```

---

### Task B2: OCRService

**Files:**
- Create: `BillSplit/Services/OCRService.swift`

- [ ] **Step 1: Create OCRService**

```swift
// BillSplit/Services/OCRService.swift
import Vision
import UIKit

class OCRService {
    static let shared = OCRService()

    func recognizeText(from image: UIImage) async throws -> [ReceiptItem] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let items = self.parseObservations(observations)
                continuation.resume(returning: items)
            }

            request.recognitionLevel = .fast
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
            request.minimumTextHeight = 0.01

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseObservations(_ observations: [VNRecognizedTextObservation]) -> [ReceiptItem] {
        var items: [ReceiptItem] = []

        // Sort by y-position (top to bottom) to maintain receipt order
        let sorted = observations.sorted { obs1, obs2 in
            let y1 = obs1.boundingBox.origin.y + obs1.boundingBox.height
            let y2 = obs2.boundingBox.origin.y + obs2.boundingBox.height
            return y1 > y2
        }

        for observation in sorted {
            guard let text = observation.topCandidates(1).first?.string else { continue }
            let confidence = observation.topCandidates(1).first?.confidence ?? 0

            guard confidence > 0.3 else { continue }

            let (description, amount) = extractAmount(from: text)

            // Skip lines that are clearly not items (headers, footers, totals)
            let lower = text.lowercased()
            if lower.contains("total") || lower.contains("合计") || lower.contains("小计") ||
               lower.contains("找零") || lower.contains("change") || lower.contains("谢谢") ||
               lower.contains("欢迎") || lower.contains("电话") || lower.contains("地址") {
                continue
            }

            let item = ReceiptItem(
                description: description.isEmpty ? text : description,
                amount: amount
            )
            items.append(item)
        }

        return items
    }

    private func extractAmount(from text: String) -> (description: String, amount: Double?) {
        // Match patterns like ¥12.50, 12.50, 12.50元, ¥12.5
        let patterns = [
            "¥\\s*(\\d+\\.?\\d*)",
            "(\\d+\\.?\\d*)\\s*元",
            "(\\d+\\.\\d{1,2})\\s*$",
            "(\\d+)\\s*$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[amountRange])
                    if let amount = Double(amountStr) {
                        // Get description (everything before the amount)
                        var desc = text
                        if let fullRange = Range(match.range, in: text) {
                            desc = String(text[text.startIndex..<fullRange.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                            // Remove trailing ¥ or other symbols
                            desc = desc.replacingOccurrences(of: "¥", with: "")
                                .trimmingCharacters(in: .whitespaces)
                        }
                        return (desc, amount)
                    }
                }
            }
        }

        return (text, nil)
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法处理这张图片"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add BillSplit/Services/OCRService.swift
git commit -m "feat: add Vision OCR service"
```

---

### Task B3: ReceiptScanView (Camera/Photo Picker + OCR)

**Files:**
- Create: `BillSplit/Views/ReceiptScanView.swift`

- [ ] **Step 1: Create ReceiptScanView**

```swift
// BillSplit/Views/ReceiptScanView.swift
import SwiftUI
import Vision

struct ReceiptScanView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
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

    private func scanImage() {
        guard let image = capturedImage else { return }
        isScanning = true
        errorMessage = nil

        Task {
            do {
                let items = try await OCRService.shared.recognizeText(from: image)
                await MainActor.run {
                    isScanning = false
                    if items.isEmpty {
                        errorMessage = "未识别到文字，请拍摄清晰的收据"
                    } else {
                        receiptItems = items
                        navigateToConfirm = true
                    }
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    errorMessage = "识别失败: \(error.localizedDescription)"
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
```

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add BillSplit/Views/ReceiptScanView.swift
git commit -m "feat: add receipt scan view with camera/picker"
```

---

### Task B4: ReceiptConfirmationView (Edit + Confirm)

**Files:**
- Create: `BillSplit/Views/ReceiptConfirmationView.swift`

- [ ] **Step 1: Create ReceiptConfirmationView**

```swift
// BillSplit/Views/ReceiptConfirmationView.swift
import SwiftUI

struct ReceiptConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @State var items: [ReceiptItem]
    let groupId: String
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String
    @State var payerId: String
    let onDismiss: () -> Void

    @State private var editingItemId: UUID?
    @State private var editDescription = ""
    @State private var editAmount = ""
    @State private var showAddItem = false
    @State private var newDescription = ""
    @State private var newAmount = ""
    @State private var newIsShared = true
    @State private var newAssignedUserId: String?

    var body: some View {
        Form {
            // Shared items section
            Section("共享项目（均分给所有成员）") {
                let sharedItems = items.filter { $0.isShared }
                if sharedItems.isEmpty {
                    Text("无共享项目")
                        .foregroundColor(.secondary)
                }
                ForEach(sharedItems) { item in
                    itemRow(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { sharedItems[$0].id }
                    items.removeAll { ids.contains($0.id) }
                }
            }

            // Personal items section
            Section("个人项目") {
                let personalItems = items.filter { !$0.isShared }
                if personalItems.isEmpty {
                    Text("无个人项目")
                        .foregroundColor(.secondary)
                }
                ForEach(personalItems) { item in
                    itemRow(item)
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { personalItems[$0].id }
                    items.removeAll { ids.contains($0.id) }
                }
            }

            // Add item
            Section {
                Button {
                    showAddItem = true
                    newDescription = ""
                    newAmount = ""
                    newIsShared = true
                    newAssignedUserId = nil
                } label: {
                    Label("添加项目", systemImage: "plus")
                }
            }

            // Payer
            Section("付款人") {
                Picker("付款人", selection: $payerId) {
                    ForEach(memberIds, id: \.self) { id in
                        Text(userNames[id] ?? "...").tag(id)
                    }
                }
            }

            // Submit
            Section {
                Button("确认生成账单") {
                    submitBills()
                }
                .disabled(items.isEmpty)
            }
        }
        .navigationTitle("收据识别")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .sheet(isPresented: $showAddItem) {
            NavigationStack {
                Form {
                    TextField("描述", text: $newDescription)
                    TextField("金额", text: $newAmount)
                        .keyboardType(.decimalPad)
                    Toggle("共享项目", isOn: $newIsShared)
                    if !newIsShared {
                        Picker("属于谁", selection: Binding(
                            get: { newAssignedUserId ?? memberIds.first ?? "" },
                            set: { newAssignedUserId = $0 }
                        )) {
                            ForEach(memberIds, id: \.self) { id in
                                Text(userNames[id] ?? "...").tag(id)
                            }
                        }
                    }
                }
                .navigationTitle("添加项目")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { showAddItem = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加") {
                            let amount = Double(newAmount)
                            items.append(ReceiptItem(
                                description: newDescription,
                                amount: amount,
                                isShared: newIsShared,
                                assignedToUserId: newIsShared ? nil : newAssignedUserId
                            ))
                            showAddItem = false
                        }
                        .disabled(newDescription.isEmpty)
                    }
                }
            }
            .presentationDetents([.height(350)])
        }
        .sheet(item: $editingItemId) { itemId in
            if let index = items.firstIndex(where: { $0.id == itemId }) {
                let item = items[index]
                NavigationStack {
                    Form {
                        TextField("描述", text: Binding(
                            get: { items[index].description },
                            set: { items[index].description = $0 }
                        ))
                        TextField("金额", text: Binding(
                            get: {
                                if let a = items[index].amount { return String(format: "%.2f", a) }
                                return ""
                            },
                            set: { items[index].amount = Double($0) }
                        ))
                        .keyboardType(.decimalPad)
                        Toggle("共享项目", isOn: $items[index].isShared)
                        if !items[index].isShared {
                            Picker("属于谁", selection: Binding(
                                get: { items[index].assignedToUserId ?? memberIds.first ?? "" },
                                set: { items[index].assignedToUserId = $0 }
                            )) {
                                ForEach(memberIds, id: \.self) { id in
                                    Text(userNames[id] ?? "...").tag(id)
                                }
                            }
                        }
                    }
                    .navigationTitle("编辑项目")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { editingItemId = nil }
                        }
                    }
                }
                .presentationDetents([.height(350)])
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: ReceiptItem) -> some View {
        HStack {
            // Toggle shared/personal
            Button {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        items[index].isShared.toggle()
                    }
                }
            } label: {
                Image(systemName: item.isShared ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isShared ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)

            // Description + amount
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description.isEmpty ? "未命名" : item.description)
                    .font(.subheadline)
                if let amount = item.amount {
                    Text(String(format: "¥%.2f", amount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Assigned user for personal items
            if !item.isShared, let userId = item.assignedToUserId {
                Text(userNames[userId] ?? "")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            // Edit button
            Button {
                editingItemId = item.id
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func submitBills() {
        let sharedItems = items.filter { $0.isShared }
        let personalItems = items.filter { !$0.isShared }

        Task {
            // Create shared bill (one merged bill for all shared items)
            if !sharedItems.isEmpty {
                let totalShared = sharedItems.reduce(0.0) { $0 + ($1.amount ?? 0) }
                let description = sharedItems.map { $0.description }.joined(separator: "、")
                try? await BillService.shared.createBill(
                    groupId: groupId,
                    payerId: payerId,
                    amount: totalShared,
                    description: description,
                    participantIds: memberIds
                )
            }

            // Create personal bills (one per item)
            for item in personalItems {
                let userId = item.assignedToUserId ?? memberIds.first ?? ""
                try? await BillService.shared.createBill(
                    groupId: groupId,
                    payerId: payerId,
                    amount: item.amount ?? 0,
                    description: item.description,
                    participantIds: [userId]
                )
            }

            await MainActor.run {
                dismiss()
                onDismiss()
            }
        }
    }
}
```

Note: `ReceiptItem` needs to conform to `Identifiable` with `UUID` — already done in Task B1.

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add BillSplit/Views/ReceiptConfirmationView.swift
git commit -m "feat: add receipt confirmation with edit/submit"
```

---

### Task B5: Modify GroupDetailView Entry Point

**Files:**
- Modify: `BillSplit/Views/GroupDetailView.swift`

- [ ] **Step 1: Replace + button with Menu**

Read current GroupDetailView.swift, find the toolbar section. Replace:

```swift
.toolbar {
    Button { showAddBill = true } label: {
        Image(systemName: "plus")
    }
}
.sheet(isPresented: $showAddBill) {
    AddBillView(...)
}
```

With:

```swift
.toolbar {
    Menu {
        Button {
            showAddBill = true
        } label: {
            Label("手动输入", systemImage: "keyboard")
        }
        Button {
            showReceiptScan = true
        } label: {
            Label("拍照识别", systemImage: "doc.text.viewfinder")
        }
    } label: {
        Image(systemName: "plus")
    }
}
.sheet(isPresented: $showAddBill) {
    AddBillView(
        groupId: vm.group.id ?? "",
        memberIds: vm.group.memberIds,
        userNames: vm.userNames,
        currentUserId: authVM.currentUserId ?? ""
    )
}
.sheet(isPresented: $showReceiptScan) {
    ReceiptScanView(
        groupId: vm.group.id ?? "",
        memberIds: vm.group.memberIds,
        userNames: vm.userNames,
        currentUserId: authVM.currentUserId ?? ""
    )
}
```

Also add the new State variable to GroupDetailView:
```swift
@State private var showReceiptScan = false
```

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add BillSplit/Views/GroupDetailView.swift
git commit -m "feat: add OCR receipt scan entry to group detail"
```

---

## Summary

| Task | Component | Files |
|------|-----------|-------|
| A1 | XcodeGen project + emulators | project.yml, BillSplitApp.swift, firebase.json, start-emulators.sh |
| B1 | ReceiptItem model | ReceiptItem.swift |
| B2 | OCRService | OCRService.swift |
| B3 | ReceiptScanView | ReceiptScanView.swift |
| B4 | ReceiptConfirmationView | ReceiptConfirmationView.swift |
| B5 | GroupDetailView mod | GroupDetailView.swift (modify) |

Total: 4 new Swift files + 1 modified + infrastructure files.
