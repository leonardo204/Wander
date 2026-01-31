import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            // Background
            WanderColors.background
                .ignoresSafeArea()

            VStack(spacing: WanderSpacing.space6) {
                // App Icon / Logo
                ZStack {
                    Circle()
                        .fill(WanderColors.primaryPale)
                        .frame(width: 120, height: 120)

                    Image(systemName: "map.fill")
                        .font(.system(size: 50))
                        .foregroundColor(WanderColors.primary)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.5)
                }

                // App Name
                VStack(spacing: WanderSpacing.space2) {
                    Text("Wander")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(WanderColors.textPrimary)

                    Text("사진으로 여행을 기록하세요")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                }
                .opacity(showContent ? 1.0 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showContent = true
            }
        }
    }
}

#Preview {
    SplashView()
}
