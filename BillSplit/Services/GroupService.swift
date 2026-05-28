import FirebaseFirestore

class GroupService {
    static let shared = GroupService()
    private let db = Firestore.firestore()

    func groupsListener(for userId: String, onUpdate: @escaping (QuerySnapshot?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                onUpdate(snapshot, error)
            }
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

    func groupListener(groupId: String, onUpdate: @escaping (DocumentSnapshot?, Error?) -> Void) -> ListenerRegistration {
        return db.collection("groups").document(groupId).addSnapshotListener { snapshot, error in
            onUpdate(snapshot, error)
        }
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
