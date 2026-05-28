# Bill Splitting App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build iOS bill-splitting app with SwiftUI + Firebase, Apple ID login, group-based bill sharing via 6-digit invite codes.

**Architecture:** SwiftUI app connects directly to Firebase (Firestore + Auth) via SDK. No custom backend. GitHub Pages hosts landing page and Universal Link handler.

**Tech Stack:** SwiftUI, Swift 5.9+, iOS 17+, Firebase Auth (Apple Sign-In), Cloud Firestore, Swift Package Manager, Xcode 15+

---

## File Structure

```
swl/
├── BillSplit/                          # iOS App (Xcode project)
│   ├── BillSplitApp.swift              # App entry + Firebase init + Auth state
│   ├── Models/
│   │   ├── User.swift                  # Firestore Codable
│   │   ├── BillGroup.swift             # Firestore Codable + inviteCode
│   │   ├── Bill.swift                  # Firestore Codable
│   │   └── Settlement.swift            # Firestore Codable
│   ├── Services/
│   │   ├── AuthService.swift           # Apple Sign-In + Firestore user write
│   │   ├── GroupService.swift          # CRUD groups, invite code lookup
│   │   ├── BillService.swift           # CRUD bills
│   │   └── SettlementService.swift     # CRUD settlements
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift         # Login state, sign-in/sign-out
│   │   ├── GroupListViewModel.swift    # Observe user's groups
│   │   ├── GroupDetailViewModel.swift  # Members, bills, debt summary
│   │   └── JoinGroupViewModel.swift    # Invite code input + validation
│   ├── Views/
│   │   ├── MainTabView.swift           # 3-tab shell
│   │   ├── LoginView.swift             # Apple ID sign-in button
│   │   ├── GroupListView.swift         # Glass card list
│   │   ├── GroupDetailView.swift       # Members + bills + debt
│   │   ├── AddBillView.swift           # Sheet: amount, desc, payer, participants
│   │   ├── JoinGroupView.swift         # 6-digit code input
│   │   ├── ProfileView.swift           # User info + logout
│   │   └── Components/
│   │       ├── GlassCard.swift         # Reusable frosted glass card
│   │       ├── SettlementRow.swift     # Single debt row
│   │       └── InviteCodeCard.swift    # Shareable invite code display
│   └── Utils/
│       └── DebtCalculator.swift        # Compute who-owes-who from bills
├── firebase/
│   ├── firestore.rules                 # Security rules
│   └── firestore.indexes.json          # Composite indexes
├── docs/                               # GitHub Pages source
│   ├── index.html                      # Landing page
│   └── apple-app-site-association      # Universal Link config
└── docs/superpowers/                   # Specs + plans (existing)
```

---

### Task 1: Create Xcode Project + Firebase Setup

**Files:**
- Create: `BillSplit/BillSplitApp.swift`
- Create: `BillSplit/Models/User.swift`
- Create: `BillSplit/Models/BillGroup.swift`
- Create: `BillSplit/Models/Bill.swift`
- Create: `BillSplit/Models/Settlement.swift`

- [ ] **Step 1: Create Xcode project**

```bash
cd /Users/zy/Desktop/swl
mkdir -p BillSplit/Models BillSplit/Services BillSplit/ViewModels BillSplit/Views/Components BillSplit/Utils
```

Note: Xcode project (.xcodeproj) must be created in Xcode GUI. Create a new iOS App project:
- Template: iOS → App
- Name: BillSplit
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: iOS 17.0
- Save to `/Users/zy/Desktop/swl/BillSplit/`

- [ ] **Step 2: Add Firebase via SPM**

In Xcode: File → Add Package Dependencies:
- `https://github.com/firebase/firebase-ios-sdk` — select `FirebaseAuth` and `FirebaseFirestore`
- `https://github.com/firebase/firebase-ios-sdk` — select `FirebaseFirestoreSwift` (for Codable support)

- [ ] **Step 3: Add GoogleService-Info.plist stub**

Create `BillSplit/GoogleService-Info.plist.stub` — placeholder. Real file comes from Firebase Console (Task 11).

- [ ] **Step 4: Create data models**

```swift
// BillSplit/Models/User.swift
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var email: String
    var createdAt: Timestamp
}
```

```swift
// BillSplit/Models/BillGroup.swift
import FirebaseFirestore

struct BillGroup: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var inviteCode: String
    var creatorId: String
    var memberIds: [String]
    var createdAt: Timestamp
}
```

```swift
// BillSplit/Models/Bill.swift
import FirebaseFirestore

struct Bill: Codable, Identifiable {
    @DocumentID var id: String?
    var groupId: String
    var payerId: String
    var amount: Double
    var description: String
    var participantIds: [String]
    var createdAt: Timestamp
}
```

```swift
// BillSplit/Models/Settlement.swift
import FirebaseFirestore

struct Settlement: Codable, Identifiable {
    @DocumentID var id: String?
    var billId: String
    var groupId: String
    var fromUserId: String
    var toUserId: String
    var amount: Double
    var status: String // "pending" | "paid"
}
```

- [ ] **Step 5: Commit**

```bash
cd /Users/zy/Desktop/swl
git init
git add -A
git commit -m "feat: init Xcode project + data models"
```

---

### Task 2: Auth Service + Login View

**Files:**
- Create: `BillSplit/Services/AuthService.swift`
- Create: `BillSplit/ViewModels/AuthViewModel.swift`
- Create: `BillSplit/Views/LoginView.swift`
- Modify: `BillSplit/BillSplitApp.swift`

- [ ] **Step 1: Write AuthService**

```swift
// BillSplit/Services/AuthService.swift
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    private let db = Firestore.firestore()

    private var currentNonce: String?

    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func saveUserIfNeeded(userId: String, displayName: String, email: String) async throws {
        let doc = try await db.collection("users").document(userId).getDocument()
        if !doc.exists {
            let user = AppUser(displayName: displayName, email: email, createdAt: Timestamp())
            try db.collection("users").document(userId).setData(from: user)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let token = credential.identityToken,
              let tokenString = String(data: token, encoding: .utf8) else { return }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        Auth.auth().signIn(with: firebaseCredential) { [weak self] result, error in
            guard let self = self, let user = result?.user else { return }
            let name = credential.fullName.map { "\($0.givenName ?? "") \($0.familyName ?? "")".trimmingCharacters(in: .whitespaces) } ?? "User"
            Task {
                try? await self.saveUserIfNeeded(userId: user.uid, displayName: name, email: user.email ?? "")
                await MainActor.run { self.objectWillChange.send() }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple failed: \(error)")
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count)] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Write AuthViewModel**

```swift
// BillSplit/ViewModels/AuthViewModel.swift
import FirebaseAuth
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserId: String?

    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isLoggedIn = user != nil
            self?.currentUserId = user?.uid
        }
    }

    deinit {
        if let handle = handle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func signOut() {
        try? AuthService.shared.signOut()
    }
}
```

- [ ] **Step 3: Write LoginView**

```swift
// BillSplit/Views/LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "dollarsign.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.tint)

                Text("账单共享")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("和朋友轻松分摊账单")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    // Handled by AuthService delegate
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}
```

- [ ] **Step 4: Update App entry point**

```swift
// BillSplit/BillSplitApp.swift
import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct BillSplitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authVM.isLoggedIn {
                MainTabView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
    }
}
```

- [ ] **Step 5: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add Apple ID auth + login view"
```

---

### Task 3: Main Tab View + Group List

**Files:**
- Create: `BillSplit/Views/MainTabView.swift`
- Create: `BillSplit/Views/GroupListView.swift`
- Create: `BillSplit/Views/Components/GlassCard.swift`
- Create: `BillSplit/Services/GroupService.swift`
- Create: `BillSplit/ViewModels/GroupListViewModel.swift`

- [ ] **Step 1: Write GlassCard component**

```swift
// BillSplit/Views/Components/GlassCard.swift
import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}
```

- [ ] **Step 2: Write GroupService**

```swift
// BillSplit/Services/GroupService.swift
import FirebaseFirestore

class GroupService {
    static let shared = GroupService()
    private let db = Firestore.firestore()

    func groupsListener(for userId: String) -> ListenerRegistration {
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener
    }

    func createGroup(name: String, creatorId: String) async throws -> BillGroup {
        let code = try await generateUniqueCode()
        let group = BillGroup(
            name: name,
            inviteCode: code,
            creatorId: creatorId,
            memberIds: [creatorId],
            createdAt: Timestamp()
        )
        let ref = try db.collection("groups").addDocument(from: group)
        var result = group
        result.id = ref.documentID
        return result
    }

    func joinGroup(inviteCode: String, userId: String) async throws -> BillGroup {
        let snapshot = try await db.collection("groups")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw GroupError.notFound
        }

        var group = try doc.data(as: BillGroup.self)
        group.id = doc.documentID

        if group.memberIds.contains(userId) {
            throw GroupError.alreadyMember
        }

        try await doc.reference.updateData([
            "memberIds": FieldValue.arrayUnion([userId])
        ])
        group.memberIds.append(userId)
        return group
    }

    func deleteGroup(_ groupId: String) async throws {
        try await db.collection("groups").document(groupId).delete()
    }

    func leaveGroup(_ groupId: String, userId: String) async throws {
        try await db.collection("groups").document(groupId).updateData([
            "memberIds": FieldValue.arrayRemove([userId])
        ])
    }

    private func generateUniqueCode() async throws -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for _ in 0..<10 {
            let code = String((0..<6).map { _ in chars.randomElement()! })
            let snapshot = try await db.collection("groups")
                .whereField("inviteCode", isEqualTo: code)
                .getDocuments()
            if snapshot.documents.isEmpty { return code }
        }
        throw GroupError.codeGenerationFailed
    }

    func groupListener(groupId: String) -> ListenerRegistration {
        db.collection("groups").document(groupId).addSnapshotListener
    }
}

enum GroupError: LocalizedError {
    case notFound
    case alreadyMember
    case codeGenerationFailed

    var errorDescription: String? {
        switch self {
        case .notFound: return "未找到账单组，请检查邀请码"
        case .alreadyMember: return "你已在该账单组中"
        case .codeGenerationFailed: return "邀请码生成失败，请重试"
        }
    }
}
```

- [ ] **Step 3: Write GroupListViewModel**

```swift
// BillSplit/ViewModels/GroupListViewModel.swift
import FirebaseFirestore
import SwiftUI

class GroupListViewModel: ObservableObject {
    @Published var groups: [BillGroup] = []
    @Published var userNames: [String: String] = [:]

    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        listener = GroupService.shared.groupsListener(for: userId) { [weak self] snapshot, error in
            guard let docs = snapshot?.documents else { return }
            let groups = docs.compactMap { try? $0.data(as: BillGroup.self) }
            self?.groups = groups

            // Fetch member names
            let allMemberIds = Set(groups.flatMap { $0.memberIds })
            self?.fetchUserNames(ids: allMemberIds)
        }
    }

    func stopListening() {
        listener?.remove()
    }

    private func fetchUserNames(ids: Set<String>) {
        for id in ids where userNames[id] == nil {
            Firestore.firestore().collection("users").document(id).getDocument { [weak self] doc, _ in
                if let user = try? doc?.data(as: AppUser.self) {
                    self?.userNames[id] = user.displayName
                }
            }
        }
    }

    func createGroup(name: String, userId: String) {
        Task {
            do {
                _ = try await GroupService.shared.createGroup(name: name, creatorId: userId)
            } catch {
                print("Create group failed: \(error)")
            }
        }
    }
}
```

- [ ] **Step 4: Write GroupListView**

```swift
// BillSplit/Views/GroupListView.swift
import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = GroupListViewModel()
    @State private var showCreateSheet = false
    @State private var newGroupName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupCard(group: group, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的账单组")
            .toolbar {
                Button { showCreateSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("账单组名称", text: $newGroupName)
                    }
                    .navigationTitle("新建账单组")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { showCreateSheet = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("创建") {
                                vm.createGroup(name: newGroupName, userId: authVM.currentUserId ?? "")
                                newGroupName = ""
                                showCreateSheet = false
                            }
                            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(200)])
            }
            .onAppear {
                if let uid = authVM.currentUserId { vm.startListening(userId: uid) }
            }
            .onDisappear { vm.stopListening() }
        }
    }
}

struct GroupCard: View {
    let group: BillGroup
    let userNames: [String: String]
    let currentUserId: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.name)
                        .font(.headline)
                    Spacer()
                    Text("\(group.memberIds.count)人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(group.inviteCode)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Text(group.createdAt.dateValue(), style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    GroupListView()
}
```

- [ ] **Step 5: Write MainTabView**

```swift
// BillSplit/Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            GroupListView()
                .tabItem {
                    Label("账单组", systemImage: "list.bullet.rectangle")
                }
            JoinGroupView()
                .tabItem {
                    Label("加入", systemImage: "person.badge.plus")
                }
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
        }
    }
}
```

- [ ] **Step 6: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add group list + glass card + create group"
```

---

### Task 4: Join Group View

**Files:**
- Create: `BillSplit/Views/JoinGroupView.swift`
- Create: `BillSplit/ViewModels/JoinGroupViewModel.swift`

- [ ] **Step 1: Write JoinGroupViewModel**

```swift
// BillSplit/ViewModels/JoinGroupViewModel.swift
import SwiftUI

class JoinGroupViewModel: ObservableObject {
    @Published var inviteCode: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var joinedGroup: BillGroup?

    func join(userId: String) {
        guard inviteCode.count == 6 else {
            errorMessage = "请输入6位邀请码"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let group = try await GroupService.shared.joinGroup(inviteCode: inviteCode, userId: userId)
                await MainActor.run {
                    self.joinedGroup = group
                    self.inviteCode = ""
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
```

- [ ] **Step 2: Write JoinGroupView**

```swift
// BillSplit/Views/JoinGroupView.swift
import SwiftUI

struct JoinGroupView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = JoinGroupViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "envelope.open.fill")
                    .resizable()
                    .frame(width: 60, height: 40)
                    .foregroundStyle(.tint)

                Text("输入邀请码加入账单组")
                    .font(.title3)
                    .fontWeight(.semibold)

                TextField("6位邀请码", text: Binding(
                    get: { vm.inviteCode },
                    set: { vm.inviteCode = String($0.prefix(6)).uppercased() }
                ))
                .textFieldStyle(.plain)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    vm.join(userId: authVM.currentUserId ?? "")
                } label: {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        Text("加入账单组")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.inviteCode.count != 6 || vm.isLoading)

                Spacer()
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("加入账单组")
            .navigationDestination(item: $vm.joinedGroup) { group in
                GroupDetailView(group: group)
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add join group with invite code"
```

---

### Task 5: Group Detail View + Bill Service

**Files:**
- Create: `BillSplit/Views/GroupDetailView.swift`
- Create: `BillSplit/Views/Components/InviteCodeCard.swift`
- Create: `BillSplit/ViewModels/GroupDetailViewModel.swift`
- Create: `BillSplit/Services/BillService.swift`
- Create: `BillSplit/Utils/DebtCalculator.swift`

- [ ] **Step 1: Write BillService**

```swift
// BillSplit/Services/BillService.swift
import FirebaseFirestore

class BillService {
    static let shared = BillService()
    private let db = Firestore.firestore()

    func billsListener(for groupId: String) -> ListenerRegistration {
        db.collection("bills")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener
    }

    func createBill(groupId: String, payerId: String, amount: Double,
                    description: String, participantIds: [String]) async throws {
        let bill = Bill(
            groupId: groupId,
            payerId: payerId,
            amount: amount,
            description: description,
            participantIds: participantIds,
            createdAt: Timestamp()
        )
        _ = try db.collection("bills").addDocument(from: bill)
    }
}
```

- [ ] **Step 2: Write DebtCalculator**

```swift
// BillSplit/Utils/DebtCalculator.swift
import Foundation

struct DebtEntry: Identifiable {
    let id = UUID()
    let fromUserId: String
    let toUserId: String
    let amount: Double
}

class DebtCalculator {
    static func compute(bills: [Bill], settlements: [Settlement]) -> [DebtEntry] {
        // net[userId] = positive means owed, negative means owes
        var net: [String: Double] = [:]

        for bill in bills {
            let share = bill.amount / Double(bill.participantIds.count)
            net[bill.payerId, default: 0] += bill.amount // payer paid for everyone
            for pid in bill.participantIds {
                net[pid, default: 0] -= share
            }
        }

        for s in settlements where s.status == "paid" {
            net[s.fromUserId, default: 0] -= s.amount
            net[s.toUserId, default: 0] += s.amount
        }

        let creditors = net.filter { $0.value > 0.01 }.sorted { $0.value > $1.value }
        let debtors = net.filter { $0.value < -0.01 }.sorted { $0.value < $1.value }

        var result: [DebtEntry] = []
        var i = 0, j = 0
        while i < creditors.count && j < debtors.count {
            let owed = creditors[i].value
            let debt = -debtors[j].value
            let amount = min(owed, debt)
            result.append(DebtEntry(fromUserId: debtors[j].key, toUserId: creditors[i].key, amount: amount))

            net[creditors[i].key]! -= amount
            net[debtors[j].key]! += amount

            if net[creditors[i].key]! < 0.01 { i += 1 }
            if net[debtors[j].key]! > -0.01 { j += 1 }
        }
        return result
    }
}
```

- [ ] **Step 3: Write GroupDetailViewModel**

```swift
// BillSplit/ViewModels/GroupDetailViewModel.swift
import FirebaseFirestore
import SwiftUI

class GroupDetailViewModel: ObservableObject {
    @Published var group: BillGroup
    @Published var bills: [Bill] = []
    @Published var settlements: [Settlement] = []
    @Published var userNames: [String: String] = [:]
    @Published var debts: [DebtEntry] = []

    private var groupListener: ListenerRegistration?
    private var billsListener: ListenerRegistration?
    private var settlementsListener: ListenerRegistration?

    init(group: BillGroup) { self.group = group }

    func startListening() {
        guard let groupId = group.id else { return }

        groupListener = GroupService.shared.groupListener(groupId: groupId) { [weak self] snapshot, _ in
            guard let self = self, let data = snapshot?.data(),
                  var g = try? Firestore.Decoder().decode(BillGroup.self, from: data) else { return }
            g.id = groupId
            self.group = g
            self.fetchUserNames(ids: Set(g.memberIds))
        }

        billsListener = BillService.shared.billsListener(for: groupId) { [weak self] snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            self?.bills = docs.compactMap { try? $0.data(as: Bill.self) }
            self?.recalcDebts()
        }

        settlementsListener = SettlementService.shared.settlementsListener(for: groupId) { [weak self] snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            self?.settlements = docs.compactMap { try? $0.data(as: Settlement.self) }
            self?.recalcDebts()
        }
    }

    func stopListening() {
        groupListener?.remove()
        billsListener?.remove()
        settlementsListener?.remove()
    }

    private func recalcDebts() {
        debts = DebtCalculator.compute(bills: bills, settlements: settlements)
    }

    private func fetchUserNames(ids: Set<String>) {
        for id in ids where userNames[id] == nil {
            Firestore.firestore().collection("users").document(id).getDocument { [weak self] doc, _ in
                if let user = try? doc?.data(as: AppUser.self) {
                    self?.userNames[id] = user.displayName
                }
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

- [ ] **Step 4: Write GroupDetailView**

```swift
// BillSplit/Views/GroupDetailView.swift
import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var vm: GroupDetailViewModel
    @State private var showAddBill = false
    @State private var showLeaveAlert = false

    init(group: BillGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Invite code
                InviteCodeCard(code: vm.group.inviteCode)

                // Members
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("成员 (\(vm.group.memberIds.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(vm.group.memberIds, id: \.self) { id in
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(id == vm.group.creatorId ? .accentColor : .secondary)
                                Text(vm.userNames[id] ?? "...")
                                if id == vm.group.creatorId { Text("创建者").font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                    }
                }

                // Debts
                if !vm.debts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("结算")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(vm.debts) { debt in
                                SettlementRow(debt: debt, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "", onMarkPaid: {
                                    markPaid(debt: debt)
                                })
                            }
                        }
                    }
                }

                // Bills
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("账单")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if vm.bills.isEmpty {
                            Text("暂无账单").foregroundColor(.secondary)
                        }
                        ForEach(vm.bills) { bill in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(bill.description)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("¥\(bill.amount, specifier: "%.2f")")
                                        .fontWeight(.semibold)
                                }
                                HStack {
                                    Text("付款: \(vm.userNames[bill.payerId] ?? "...")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(bill.createdAt.dateValue(), style: .date)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            if bill.id != vm.bills.last?.id { Divider() }
                        }
                    }
                }

                // Actions
                VStack(spacing: 8) {
                    if vm.group.creatorId == authVM.currentUserId {
                        Button(role: .destructive) {
                            vm.deleteGroup(userId: authVM.currentUserId ?? "")
                        } label: {
                            Label("删除账单组", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            if vm.canLeave(userId: authVM.currentUserId ?? "") {
                                showLeaveAlert = true
                            } else {
                                vm.leaveGroup(userId: authVM.currentUserId ?? "")
                            }
                        } label: {
                            Label("退出账单组", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button { showAddBill = true } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showAddBill) {
            AddBillView(groupId: vm.group.id ?? "", memberIds: vm.group.memberIds, userNames: vm.userNames, currentUserId: authVM.currentUserId ?? "")
        }
        .alert("有未结清欠款", isPresented: $showLeaveAlert) {
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先结清所有欠款后再退出账单组")
        }
        .onAppear { vm.startListening() }
        .onDisappear { vm.stopListening() }
    }

    private func markPaid(debt: DebtEntry) {
        guard let groupId = vm.group.id else { return }
        Task {
            try? await SettlementService.shared.createSettlement(
                groupId: groupId, fromUserId: debt.fromUserId,
                toUserId: debt.toUserId, amount: debt.amount
            )
        }
    }
}
```

- [ ] **Step 5: Write SettlementRow**

```swift
// BillSplit/Views/Components/SettlementRow.swift
import SwiftUI

struct SettlementRow: View {
    let debt: DebtEntry
    let userNames: [String: String]
    let currentUserId: String
    let onMarkPaid: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isPayer ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(isPayer ? .red : .green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                if isPayer {
                    Text("你 → \(userNames[debt.toUserId] ?? "...")")
                        .font(.subheadline)
                } else {
                    Text("\(userNames[debt.fromUserId] ?? "...") → 你")
                        .font(.subheadline)
                }
                Text("¥\(debt.amount, specifier: "%.2f")")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            if isPayer {
                Button("标记已还") { onMarkPaid() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var isPayer: Bool { debt.fromUserId == currentUserId }
}
```

- [ ] **Step 6: Write InviteCodeCard**

```swift
// BillSplit/Views/Components/InviteCodeCard.swift
import SwiftUI

struct InviteCodeCard: View {
    let code: String

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(code)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}
```

- [ ] **Step 7: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add group detail with bills, debts, settlement"
```

---

### Task 6: Add Bill View + Settlement Service

**Files:**
- Create: `BillSplit/Views/AddBillView.swift`
- Create: `BillSplit/Services/SettlementService.swift`

- [ ] **Step 1: Write SettlementService**

```swift
// BillSplit/Services/SettlementService.swift
import FirebaseFirestore

class SettlementService {
    static let shared = SettlementService()
    private let db = Firestore.firestore()

    func settlementsListener(for groupId: String) -> ListenerRegistration {
        db.collection("settlements")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener
    }

    func createSettlement(groupId: String, fromUserId: String, toUserId: String, amount: Double) async throws {
        let settlement = Settlement(
            billId: "",
            groupId: groupId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amount,
            status: "paid"
        )
        _ = try db.collection("settlements").addDocument(from: settlement)
    }
}
```

- [ ] **Step 2: Write AddBillView**

```swift
// BillSplit/Views/AddBillView.swift
import SwiftUI

struct AddBillView: View {
    @Environment(\.dismiss) var dismiss
    let groupId: String
    let memberIds: [String]
    let userNames: [String: String]
    let currentUserId: String

    @State private var amountText = ""
    @State private var description = ""
    @State private var selectedPayerId: String
    @State private var selectedParticipantIds: Set<String>

    init(groupId: String, memberIds: [String], userNames: [String: String], currentUserId: String) {
        self.groupId = groupId
        self.memberIds = memberIds
        self.userNames = userNames
        self.currentUserId = currentUserId
        _selectedPayerId = State(initialValue: currentUserId)
        _selectedParticipantIds = State(initialValue: Set(memberIds))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }

                Section("描述") {
                    TextField("例如: 晚餐", text: $description)
                }

                Section("付款人") {
                    Picker("付款人", selection: $selectedPayerId) {
                        ForEach(memberIds, id: \.self) { id in
                            Text(userNames[id] ?? "...").tag(id)
                        }
                    }
                }

                Section("参与人") {
                    ForEach(memberIds, id: \.self) { id in
                        HStack {
                            Text(userNames[id] ?? "...")
                            Spacer()
                            if selectedParticipantIds.contains(id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedParticipantIds.contains(id) {
                                if selectedParticipantIds.count > 1 {
                                    selectedParticipantIds.remove(id)
                                }
                            } else {
                                selectedParticipantIds.insert(id)
                            }
                        }
                    }
                }

                Section {
                    Button("提交账单") {
                        submit()
                    }
                    .disabled(amountValue == nil || description.trimmingCharacters(in: .whitespaces).isEmpty || selectedParticipantIds.isEmpty)
                }
            }
            .navigationTitle("新建账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private var amountValue: Double? {
        Double(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private func submit() {
        guard let amount = amountValue else { return }
        Task {
            try? await BillService.shared.createBill(
                groupId: groupId,
                payerId: selectedPayerId,
                amount: amount,
                description: description,
                participantIds: Array(selectedParticipantIds)
            )
            await MainActor.run { dismiss() }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add bill creation + settlement service"
```

---

### Task 7: Profile View

**Files:**
- Create: `BillSplit/Views/ProfileView.swift`

- [ ] **Step 1: Write ProfileView**

```swift
// BillSplit/Views/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text("用户 ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(authVM.currentUserId ?? "")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
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
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add profile view"
```

---

### Task 8: GitHub Pages Landing Page

**Files:**
- Create: `docs/index.html`
- Create: `docs/apple-app-site-association`

- [ ] **Step 1: Write landing page**

```html
<!-- docs/index.html -->
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="apple-itunes-app" content="app-id=YOUR_APP_ID">
    <title>账单共享 - BillSplit</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex; align-items: center; justify-content: center;
            color: white;
        }
        .card {
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-radius: 24px;
            padding: 48px 32px;
            text-align: center;
            max-width: 400px;
            width: 90%;
            box-shadow: 0 20px 60px rgba(0,0,0,0.2);
        }
        h1 { font-size: 2.5rem; margin-bottom: 8px; }
        p { opacity: 0.85; margin-bottom: 32px; font-size: 1.1rem; }
        .badge {
            display: inline-block;
            background: white;
            color: #764ba2;
            padding: 12px 32px;
            border-radius: 100px;
            font-weight: 600;
            text-decoration: none;
            transition: transform 0.2s;
        }
        .badge:hover { transform: scale(1.05); }
        .footer { margin-top: 24px; opacity: 0.5; font-size: 0.8rem; }
    </style>
</head>
<body>
    <div class="card">
        <h1>📋</h1>
        <h1>账单共享</h1>
        <p>和朋友轻松分摊账单<br>Apple ID 登录 · 邀请码加入</p>
        <a href="https://apps.apple.com/app/idYOUR_APP_ID" class="badge">App Store 下载</a>
        <p class="footer">BillSplit · iOS 17+</p>
    </div>
</body>
</html>
```

- [ ] **Step 2: Write apple-app-site-association**

```json
// docs/apple-app-site-association
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appID": "TEAM_ID.com.yourcompany.billsplit",
                "paths": ["/invite/*"]
            }
        ]
    }
}
```

Note: Replace `TEAM_ID` and `com.yourcompany.billsplit` with actual values from Apple Developer.

- [ ] **Step 3: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add GitHub Pages landing page + Universal Link"
```

---

### Task 9: Firebase Security Rules

**Files:**
- Create: `firebase/firestore.rules`
- Create: `firebase/firestore.indexes.json`

- [ ] **Step 1: Write Firestore security rules**

```javascript
// firebase/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    match /groups/{groupId} {
      allow read: if request.auth != null
        && request.auth.uid in resource.data.memberIds;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.creatorId;
      allow update: if request.auth != null
        && request.auth.uid in resource.data.memberIds
        && request.auth.uid == resource.data.creatorId;
      allow delete: if request.auth != null
        && request.auth.uid == resource.data.creatorId;
    }

    match /bills/{billId} {
      allow read: if request.auth != null
        && exists(/databases/$(database)/documents/groups/$(resource.data.groupId))
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(resource.data.groupId)).data.memberIds;
      allow create: if request.auth != null
        && request.auth.uid == request.resource.data.payerId
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(request.resource.data.groupId)).data.memberIds;
    }

    match /settlements/{settlementId} {
      allow read: if request.auth != null
        && exists(/databases/$(database)/documents/groups/$(resource.data.groupId))
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(resource.data.groupId)).data.memberIds;
      allow create: if request.auth != null
        && (request.auth.uid == request.resource.data.fromUserId
            || request.auth.uid == request.resource.data.toUserId);
    }
  }
}
```

- [ ] **Step 2: Write Firestore indexes**

```json
// firebase/firestore.indexes.json
{
  "indexes": [
    {
      "collectionGroup": "groups",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "memberIds", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "bills",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "groupId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "settlements",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "groupId", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "groups",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "inviteCode", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "feat: add Firestore security rules + indexes"
```

---

### Task 10: Firebase Console Setup + Deploy

**Files:** None (manual steps in Firebase Console)

- [ ] **Step 1: Create Firebase project**

1. Go to https://console.firebase.google.com
2. Create new project: `billsplit-app`
3. Add iOS app: bundle ID = `com.yourcompany.billsplit`
4. Download `GoogleService-Info.plist` → drag into Xcode project root

- [ ] **Step 2: Enable Apple Sign-In**

1. Firebase Console → Authentication → Sign-in method
2. Enable Apple → configure with Apple Developer team info

- [ ] **Step 3: Create Firestore database**

1. Firestore Database → Create database
2. Start in test mode (security rules deployed later)
3. Region: `asia-east1` (or nearest)

- [ ] **Step 4: Deploy security rules + indexes**

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

- [ ] **Step 5: Deploy GitHub Pages**

1. Push code to GitHub repo `<username>.github.io`
2. Settings → Pages → Source: `main` branch, `/docs` folder
3. Verify `https://<username>.github.io/apple-app-site-association` returns JSON

- [ ] **Step 6: Test on iOS simulator**

1. Build & run in Xcode (iOS 17 simulator)
2. Sign in with Apple (Simulator supports test Apple ID)
3. Create group → copy invite code → sign in as another user → join
4. Add bills → verify debt calculation
5. Mark settlement → verify status update

- [ ] **Step 7: Commit final config**

```bash
cd /Users/zy/Desktop/swl
git add -A
git commit -m "chore: final Firebase + deploy config"
```

---

## Summary

| Task | Component | Files Created |
|------|-----------|---------------|
| 1 | Project scaffold + models | 5 |
| 2 | Auth service + login | 4 |
| 3 | Group list + glass UI | 5 |
| 4 | Join group | 2 |
| 5 | Group detail + debt calc | 5 |
| 6 | Add bill + settlements | 2 |
| 7 | Profile | 1 |
| 8 | GitHub Pages | 2 |
| 9 | Firebase rules | 2 |
| 10 | Deploy + test | 0 (manual) |

Total: ~24 source files created. Estimated implementation time: 4-6 hours.
