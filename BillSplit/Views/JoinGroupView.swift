import SwiftUI

struct JoinGroupView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = JoinGroupViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
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
                }
                .padding()
            }
            .navigationTitle("加入账单组")
            .navigationDestination(item: $vm.joinedGroup) { group in
                GroupDetailView(group: group)
            }
        }
    }
}
