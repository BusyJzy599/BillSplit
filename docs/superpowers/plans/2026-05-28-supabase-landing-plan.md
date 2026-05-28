# Supabase 落地 + 实时更新 + 头像 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 填入真实 Supabase 凭证，添加实时账单同步和用户头像功能，app 本地跑通可上 TestFlight。

**Architecture:** Supabase Realtime 通过 WebSocket 推送 bills/settlements 表变更到客户端，GroupDetailViewModel 监听变更后刷新数据。头像通过 Supabase Storage 存储，PhotosPicker 选图后本地压缩上传。

**Tech Stack:** SwiftUI, Swift 5.9+, iOS 17+, Supabase Swift SDK, Supabase Realtime, Supabase Storage

---

## File Structure

```
swl/
├── BillSplit/
│   ├── BillSplitApp.swift              # 改: 真实凭证
│   ├── Models/
│   │   └── User.swift                  # 改: +avatarUrl
│   ├── Services/
│   │   ├── StorageService.swift        # 新: 头像上传/压缩
│   │   └── RealtimeService.swift       # 新: 实时订阅
│   ├── ViewModels/
│   │   └── GroupDetailViewModel.swift  # 改: 实时监听
│   ├── Views/
│   │   ├── ProfileView.swift           # 改: 头像 + 编辑入口
│   │   ├── EditProfileView.swift       # 新: 编辑资料
│   │   ├── GroupDetailView.swift       # 改: 头像
│   │   ├── GroupListView.swift         # 改: 头像
│   │   └── Components/
│   │       ├── AvatarView.swift        # 新: 头像组件
│   │       └── SettlementRow.swift     # 改: 头像
│   └── Utils/
│       └── ImageCompressor.swift       # 新: 图片压缩工具
├── supabase/
│   └── migration.sql                   # 改: +avatar_url, +storage policies
```

---

### Task 1: 填入 Supabase 真实凭证

**Files:**
- Modify: `BillSplit/BillSplitApp.swift`

- [ ] **Step 1: 更新 Supabase 客户端初始化**

Replace placeholder credentials with real ones:

```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://prmjucdsuejtdxxyucxo.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBybWp1Y2RzdWVqdGR4eHl1Y3hvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjM0MjUsImV4cCI6MjA5NTUzOTQyNX0.UgcwvOxXaUoOPyRwnIjnZz8_vkmwfLsZX25_nozhnFw"
)
```

- [ ] **Step 2: Commit**

```bash
git add BillSplit/BillSplitApp.swift
git commit -m "feat: add real Supabase project credentials"
```

---

### Task 2: AppUser 模型加 avatarUrl

**Files:**
- Modify: `BillSplit/Models/User.swift`

- [ ] **Step 1: 添加 avatarUrl 字段**

```swift
struct AppUser: Codable, Identifiable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var avatarUrl: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BillSplit/Models/User.swift
git commit -m "feat: add avatarUrl to AppUser model"
```

---

### Task 3: 创建 StorageService

**Files:**
- Create: `BillSplit/Services/StorageService.swift`
- Create: `BillSplit/Utils/ImageCompressor.swift`

- [ ] **Step 1: 创建 ImageCompressor**

```swift
// BillSplit/Utils/ImageCompressor.swift
import UIKit

enum ImageCompressor {
    static func compressForAvatar(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 512
        let size = image.size
        let scale: CGFloat
        if size.width > size.height {
            scale = min(maxDimension / size.width, 1.0)
        } else {
            scale = min(maxDimension / size.height, 1.0)
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: 0.7)
    }
}
```

- [ ] **Step 2: 创建 StorageService**

```swift
// BillSplit/Services/StorageService.swift
import Foundation
import Supabase

class StorageService {
    static let shared = StorageService()
    private let bucket = "avatars"

    func uploadAvatar(userId: String, image: UIImage) async throws -> String {
        guard let imageData = ImageCompressor.compressForAvatar(image) else {
            throw StorageError.compressFailed
        }

        let filePath = "\(userId)/avatar.jpg"
        try await supabase.storage
            .from(bucket)
            .upload(path: filePath, data: imageData, options: .init(upsert: true))

        return try supabase.storage
            .from(bucket)
            .getPublicURL(path: filePath)
            .absoluteString
    }

    func deleteAvatar(userId: String) async throws {
        let filePath = "\(userId)/avatar.jpg"
        try await supabase.storage
            .from(bucket)
            .remove(paths: [filePath])
    }
}

enum StorageError: LocalizedError {
    case compressFailed

    var errorDescription: String? {
        switch self {
        case .compressFailed: return "图片压缩失败"
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add BillSplit/Services/StorageService.swift BillSplit/Utils/ImageCompressor.swift
git commit -m "feat: add StorageService for avatar upload"
```

---

### Task 4: 创建 RealtimeService

**Files:**
- Create: `BillSplit/Services/RealtimeService.swift`

- [ ] **Step 1: 创建 RealtimeService**

```swift
// BillSplit/Services/RealtimeService.swift
import Foundation
import Supabase

class RealtimeService {
    static let shared = RealtimeService()

    private var channels: [String: RealtimeChannelV2] = [:]

    func subscribeBills(groupId: Int, onChange: @escaping () -> Void) {
        let channelId = "bills-\(groupId)"
        guard channels[channelId] == nil else { return }

        let channel = supabase.realtime.channel(channelId)
        Task {
            await channel.on(.postgresChange, table: "bills") { _ in
                onChange()
            }
            await channel.subscribe()
        }
        channels[channelId] = channel
    }

    func subscribeSettlements(groupId: Int, onChange: @escaping () -> Void) {
        let channelId = "settlements-\(groupId)"
        guard channels[channelId] == nil else { return }

        let channel = supabase.realtime.channel(channelId)
        Task {
            await channel.on(.postgresChange, table: "settlements") { _ in
                onChange()
            }
            await channel.subscribe()
        }
        channels[channelId] = channel
    }

    func unsubscribe(groupId: Int) {
        let billsId = "bills-\(groupId)"
        let settlementsId = "settlements-\(groupId)"

        if let channel = channels.removeValue(forKey: billsId) {
            Task { await channel.unsubscribe() }
        }
        if let channel = channels.removeValue(forKey: settlementsId) {
            Task { await channel.unsubscribe() }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BillSplit/Services/RealtimeService.swift
git commit -m "feat: add RealtimeService for live bill updates"
```

---

### Task 5: GroupDetailViewModel 集成实时监听

**Files:**
- Modify: `BillSplit/ViewModels/GroupDetailViewModel.swift`

- [ ] **Step 1: 添加实时订阅和取消**

```swift
// BillSplit/ViewModels/GroupDetailViewModel.swift
import SwiftUI
import Supabase

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = []
    @Published var debts: [DebtEntry] = []

    init(group: BillGroup) { self.group = group }

    func loadData() {
        guard let groupId = group.id else { return }
        Task {
            do {
                let g = try await GroupService.shared.getGroup(id: groupId)
                await MainActor.run { self.group = g }
                await fetchUserNames(ids: Set(g.memberIds))

                let bills = try await BillService.shared.getBills(for: groupId)
                await MainActor.run { self.bills = bills }

                let settlements = try await SettlementService.shared.getSettlements(for: groupId)
                await MainActor.run { self.settlements = settlements }

                await MainActor.run { recalcDebts() }

                // Start realtime subscriptions after initial load
                subscribeRealtime()
            } catch {
                print("Load data failed: \(error)")
            }
        }
    }

    func subscribeRealtime() {
        guard let groupId = group.id else { return }
        RealtimeService.shared.subscribeBills(groupId: groupId) { [weak self] in
            self?.refreshData()
        }
        RealtimeService.shared.subscribeSettlements(groupId: groupId) { [weak self] in
            self?.refreshData()
        }
    }

    func unsubscribeRealtime() {
        guard let groupId = group.id else { return }
        RealtimeService.shared.unsubscribe(groupId: groupId)
    }

    private func refreshData() {
        guard let groupId = group.id else { return }
        Task {
            do {
                let bills = try await BillService.shared.getBills(for: groupId)
                let settlements = try await SettlementService.shared.getSettlements(for: groupId)
                await MainActor.run {
                    self.bills = bills
                    self.settlements = settlements
                    recalcDebts()
                }
            } catch {
                print("Refresh failed: \(error)")
            }
        }
    }

    private func recalcDebts() {
        debts = DebtCalculator.compute(bills: bills, settlements: settlements)
    }

    private func fetchUserNames(ids: Set<String>) async {
        for id in ids where userNames[id] == nil {
            do {
                let users: [AppUser] = try await supabase.from("users").select().eq("id", value: id).execute().value
                if let user = users.first {
                    await MainActor.run { self.userNames[id] = user.displayName }
                }
            } catch {
                print("Fetch user failed: \(error)")
            }
        }
    }

    func deleteGroup(userId: String) {
        guard let groupId = group.id else { return }
        Task {
            try? await GroupService.shared.deleteGroup(groupId)
        }
    }

    func leaveGroup(userId: String) {
        guard let groupId = group.id else { return }
        Task {
            try? await GroupService.shared.leaveGroup(groupId, userId: userId)
        }
    }

    func canLeave(userId: String) -> Bool {
        debts.contains { $0.fromUserId == userId || $0.toUserId == userId }
    }
}
```

- [ ] **Step 2: 在 GroupDetailView 中调用 unsubscribeRealtime**

在 `GroupDetailView.swift` 添加 `.onDisappear`:

```swift
.onAppear { vm.loadData() }
.onDisappear { vm.unsubscribeRealtime() }
```

- [ ] **Step 3: Commit**

```bash
git add BillSplit/ViewModels/GroupDetailViewModel.swift BillSplit/Views/GroupDetailView.swift
git commit -m "feat: integrate RealtimeService into GroupDetailViewModel"
```

---

### Task 6: 创建 AvatarView 组件

**Files:**
- Create: `BillSplit/Views/Components/AvatarView.swift`

- [ ] **Step 1: 创建 AvatarView**

```swift
// BillSplit/Views/Components/AvatarView.swift
import SwiftUI
import Supabase

struct AvatarView: View {
    let avatarUrl: String?
    let displayName: String
    let size: CGFloat

    var body: some View {
        if let avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    fallbackView
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                @unknown default:
                    fallbackView
                }
            }
        } else {
            fallbackView
        }
    }

    private var fallbackView: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(.tint)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add BillSplit/Views/Components/AvatarView.swift
git commit -m "feat: add AvatarView component"
```

---

### Task 7: ProfileView + EditProfileView

**Files:**
- Create: `BillSplit/Views/EditProfileView.swift`
- Modify: `BillSplit/Views/ProfileView.swift`

- [ ] **Step 1: 创建 EditProfileView**

```swift
// BillSplit/Views/EditProfileView.swift
import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var displayName: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var avatarUrl: String?
    @State private var isUploading = false

    init(displayName: String, avatarUrl: String?) {
        _displayName = State(initialValue: displayName)
        _avatarUrl = State(initialValue: avatarUrl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            AvatarView(
                                avatarUrl: avatarUrl,
                                displayName: displayName,
                                size: 100
                            )
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("选择照片", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        loadImage(from: newItem)
                    }
                }

                Section("名字") {
                    TextField("显示名称", text: $displayName)
                }

                Section {
                    Button("保存") {
                        save()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isUploading)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { self.selectedImage = image }
            }
        }
    }

    private func save() {
        guard let userId = authVM.currentUserId else { return }
        isUploading = true

        Task {
            // Update display name
            try? await supabase.from("users")
                .update(["display_name": displayName])
                .eq("id", value: userId)
                .execute()

            // Upload avatar if new image selected
            if let image = selectedImage,
               let url = try? await StorageService.shared.uploadAvatar(userId: userId, image: image) {
                try? await supabase.from("users")
                    .update(["avatar_url": url])
                    .eq("id", value: userId)
                    .execute()
            }

            await MainActor.run {
                isUploading = false
                dismiss()
            }
        }
    }
}
```

- [ ] **Step 2: 改造 ProfileView**

在 `ProfileView.swift` 中，替换现有的 Section 内容，添加用户信息获取和编辑入口：

```swift
// BillSplit/Views/ProfileView.swift
import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var displayName: String = ""
    @State private var avatarUrl: String?
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        AvatarView(avatarUrl: avatarUrl, displayName: displayName, size: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "用户" : displayName)
                                .font(.headline)
                            Text(authVM.currentUserId ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button(role: .destructive) {
                        authVM.signOut()
                    } label: {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("个人中心")
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(displayName: displayName, avatarUrl: avatarUrl)
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    private func loadProfile() {
        guard let userId = authVM.currentUserId else { return }
        Task {
            do {
                let users: [AppUser] = try await supabase.from("users").select().eq("id", value: userId).execute().value
                if let user = users.first {
                    await MainActor.run {
                        self.displayName = user.displayName
                        self.avatarUrl = user.avatarUrl
                    }
                }
            } catch {
                print("Load profile failed: \(error)")
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add BillSplit/Views/EditProfileView.swift BillSplit/Views/ProfileView.swift
git commit -m "feat: add EditProfileView and update ProfileView with avatar"
```

---

### Task 8: 在成员列表、账单行、结算行显示头像

**Files:**
- Modify: `BillSplit/Views/GroupDetailView.swift`
- Modify: `BillSplit/Views/GroupListView.swift`
- Modify: `BillSplit/Views/Components/SettlementRow.swift`
- Modify: `BillSplit/ViewModels/GroupDetailViewModel.swift`
- Modify: `BillSplit/ViewModels/GroupListViewModel.swift`

- [ ] **Step 1: ViewModel 存储头像 URL**

在 `GroupListViewModel.swift` 中，添加 `userAvatars`:

```swift
@Published var userAvatars: [String: String] = [:]
```

在 `fetchUserNames` 中，同时获取头像:

```swift
private func fetchUserNames(ids: Set<String>) async {
    for id in ids where userNames[id] == nil {
        do {
            let users: [AppUser] = try await supabase.from("users").select().eq("id", value: id).execute().value
            if let user = users.first {
                await MainActor.run {
                    self.userNames[id] = user.displayName
                    self.userAvatars[id] = user.avatarUrl
                }
            }
        } catch {
            print("Fetch user failed: \(error)")
        }
    }
}
```

在 `GroupDetailViewModel.swift` 中，同样添加 `@Published var userAvatars: [String: String] = [:]` 并在 `fetchUserNames` 中同步写入。

- [ ] **Step 2: GroupCard (GroupListView) 添加头像**

在 `GroupCard` 中，取第一个成员头像显示：

```swift
struct GroupCard: View {
    let group: BillGroup
    let userNames: [String: String]
    let userAvatars: [String: String]
    let currentUserId: String
    // ... existing content, add avatar before group name:
    // HStack {
    //     AvatarView(avatarUrl: userAvatars[group.creatorId], displayName: userNames[group.creatorId] ?? "", size: 24)
    //     Text(group.name).font(.headline)
    //     Spacer()
    //     ...
    // }
}
```

- [ ] **Step 3: GroupDetailView 成员列表加头像**

在 `GroupDetailView` 成员 ForEach 中，将 `Image(systemName: "person.circle.fill")` 替换为：

```swift
AvatarView(
    avatarUrl: vm.userAvatars[id],
    displayName: vm.userNames[id] ?? "",
    size: 32
)
```

- [ ] **Step 4: SettlementRow 加头像**

在 `SettlementRow` 中，添加头像显示（对方用户的小头像）：

```swift
// Before the VStack with name:
AvatarView(
    avatarUrl: isPayer ? userAvatars[debt.toUserId] : userAvatars[debt.fromUserId],
    displayName: isPayer ? (userNames[debt.toUserId] ?? "") : (userNames[debt.fromUserId] ?? ""),
    size: 36
)
```

需要给 `SettlementRow` 传入 `userAvatars`。

- [ ] **Step 5: Commit**

```bash
git add BillSplit/Views/GroupDetailView.swift BillSplit/Views/GroupListView.swift BillSplit/Views/Components/SettlementRow.swift BillSplit/ViewModels/GroupDetailViewModel.swift BillSplit/ViewModels/GroupListViewModel.swift
git commit -m "feat: display avatars across group member lists, cards, and settlements"
```

---

### Task 9: 更新迁移文件 + Storage bucket RLS

**Files:**
- Modify: `supabase/migration.sql`

- [ ] **Step 1: 更新 migration.sql 添加 avatar_url 和 storage policies**

在 `migration.sql` 末尾追加：

```sql
-- Storage bucket policies (run in SQL editor for avatars bucket)
-- Or create bucket manually in dashboard: avatars (public)

-- Avatar URL column (already in users table if migration re-run)
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Storage RLS: public read for avatars bucket
-- These apply after creating the 'avatars' bucket via dashboard
DROP POLICY IF EXISTS "Avatars are publicly viewable" ON storage.objects;
CREATE POLICY "Avatars are publicly viewable" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload avatar" ON storage.objects;
CREATE POLICY "Users can upload avatar" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migration.sql
git commit -m "chore: update migration with avatar_url and storage policies"
```

---

### Task 10: 创建 avatars Storage bucket

通过 Supabase Dashboard 或 MCP 执行:

- [ ] **Step 1: 创建 storage bucket**

Supabase Dashboard → Storage → New Bucket → `avatars` → Public

或通过 SQL（需要 storage 扩展权限）:

```sql
INSERT INTO storage.buckets (id, name, public, avif_autodetection)
VALUES ('avatars', 'avatars', true, false)
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 2: 执行 storage RLS policies**

将 Task 9 中的 storage RLS policies 在 Supabase SQL Editor 中执行。

---

### Task 11: Xcode 编译验证

- [ ] **Step 1: 在 Xcode 中打开项目**

```bash
open BillSplit/BillSplit.xcodeproj
```

- [ ] **Step 2: 编译项目**

在 Xcode 中选择 iOS Simulator target，Product → Build (⌘B)

Expected: Build succeeds, no compile errors.

- [ ] **Step 3: 运行 app**

Product → Run (⌘R) in simulator

- [ ] **Step 4: 烟雾测试**

- [ ] Apple Sign In 弹窗出现
- [ ] 登录后看到主界面（空账单组列表）
- [ ] 创建账单组
- [ ] 添加账单
- [ ] 编辑个人资料（头像 + 名字）

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: final verification changes"
```

---

### Task 12: TestFlight 准备

- [ ] **Step 1: 确保 Sign In with Apple capability 正确配置**

在 Xcode → Target → Signing & Capabilities → 确保 Apple Sign In 已添加。

- [ ] **Step 2: Archive and upload**

Xcode → Product → Archive → Distribute App → TestFlight

- [ ] **Step 3: 确认 Supabase 生产环境就绪**

- [ ] Auth: Apple provider 在 Supabase Dashboard 已配置
- [ ] RLS policies 正确
- [ ] Storage bucket 已创建
- [ ] Realtime 已启用
