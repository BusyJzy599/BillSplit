import Foundation
import Supabase

class GroupService {
    static let shared = GroupService()

    func getGroups(for userId: String) async throws -> [BillGroup] {
        let groups: [BillGroup] = try await supabase.from("groups").select().contains("member_ids", value: [userId]).order("created_at", ascending: false).execute().value
        return groups
    }

    func getGroup(id: Int) async throws -> BillGroup {
        let groups: [BillGroup] = try await supabase.from("groups").select().eq("id", value: id).execute().value
        guard let group = groups.first else { throw GroupError.notFound }
        return group
    }

    func createGroup(name: String, creatorId: String) async throws -> BillGroup {
        let code = try await generateUniqueCode()
        var group = BillGroup(
            name: name,
            inviteCode: code,
            creatorId: creatorId,
            memberIds: [creatorId],
            icon: "👥",
            createdAt: Date()
        )
        group.memberIds = Array(Set(group.memberIds))
        let result: [BillGroup] = try await supabase.from("groups").insert(group).select().execute().value
        guard let created = result.first else { throw GroupError.codeGenerationFailed }
        return created
    }

    func joinGroup(inviteCode: String, userId: String) async throws -> BillGroup {
        let groups: [BillGroup] = try await supabase.from("groups").select().eq("invite_code", value: inviteCode.uppercased()).execute().value

        guard var group = groups.first else {
            throw GroupError.notFound
        }

        if group.memberIds.contains(userId) {
            throw GroupError.alreadyMember
        }

        group.memberIds.append(userId)
        group.memberIds = Array(Set(group.memberIds))
        try await supabase.from("groups").update(["member_ids": group.memberIds]).eq("id", value: group.id!).execute()
        return group
    }

    func deleteGroup(_ groupId: Int) async throws {
        try await supabase.from("groups").delete().eq("id", value: groupId).execute()
    }

    func leaveGroup(_ groupId: Int, userId: String) async throws {
        let group = try await getGroup(id: groupId)
        let newMemberIds = group.memberIds.filter { $0 != userId }
        try await supabase.from("groups").update(["member_ids": newMemberIds]).eq("id", value: groupId).execute()
    }

    private func generateUniqueCode() async throws -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        for _ in 0..<10 {
            let code = String((0..<6).map { _ in chars.randomElement()! })
            let existing: [BillGroup] = try await supabase.from("groups").select().eq("invite_code", value: code).execute().value
            if existing.isEmpty { return code }
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
        case .notFound: return "Group not found. Check the invite code."
        case .alreadyMember: return "You are already in this group."
        case .codeGenerationFailed: return "Failed to generate invite code. Try again."
        }
    }
}
