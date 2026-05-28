import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

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

                Button {
                    authService.startSignInWithAppleFlow()
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .resizable()
                            .frame(width: 20, height: 24)
                        Text("使用 Apple 登录")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}
