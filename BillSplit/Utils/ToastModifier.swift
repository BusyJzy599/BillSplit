import SwiftUI

struct Toast: Equatable {
    let message: String
    let icon: String
    let isError: Bool

    static func success(_ msg: String) -> Toast { Toast(message: msg, icon: "checkmark.circle.fill", isError: false) }
    static func error(_ msg: String) -> Toast { Toast(message: msg, icon: "xmark.circle.fill", isError: true) }
    static func info(_ msg: String) -> Toast { Toast(message: msg, icon: "info.circle.fill", isError: false) }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = toast {
                HStack(spacing: 8) {
                    Image(systemName: toast.icon)
                        .foregroundColor(toast.isError ? .red : .green)
                    Text(toast.message).font(.subheadline).fontWeight(.medium)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 8)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.toast = nil }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}
