import SwiftUI

class JoinGroupViewModel: ObservableObject {
    @Published var inviteCode: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var joinedGroup: BillGroup?

    func join(userId: String) {
        guard inviteCode.count == 6 else {
            errorMessage = LocaleManager.shared.locale == .zh ? "请输入6位邀请码" : "Please enter a 6-digit code"
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
                    NotificationCenter.default.post(name: NSNotification.Name("refreshGroups"), object: nil)
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
