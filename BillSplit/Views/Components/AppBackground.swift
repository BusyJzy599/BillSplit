import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            // Base gradient matching app icon
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.13, blue: 0.27), Color(red: 0.12, green: 0.16, blue: 0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft teal/blue glow accents
            Circle()
                .fill(Color(red: 0, green: 0.82, blue: 0.69).opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -200)

            Circle()
                .fill(Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 100)

            // Subtle top highlight
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.03), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
                .ignoresSafeArea()
                .offset(y: -100)
        }
    }
}

// Light mode variant with softer colors
struct AppBackgroundLight: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            Circle()
                .fill(Color(red: 0, green: 0.82, blue: 0.69).opacity(0.04))
                .frame(width: 250)
                .blur(radius: 60)
                .offset(x: -60, y: -150)

            Circle()
                .fill(Color(red: 0.36, green: 0.61, blue: 0.84).opacity(0.04))
                .frame(width: 200)
                .blur(radius: 50)
                .offset(x: 80, y: 80)
        }
    }
}

#Preview {
    AppBackground()
}
