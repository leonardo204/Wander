import SwiftUI

struct OnboardingIntroView: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            // Illustration
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(WanderColors.primary)

            VStack(spacing: WanderSpacing.space3) {
                Text("사진으로 여행을 기록하세요")
                    .wanderTitle1()
                    .multilineTextAlignment(.center)

                Text("사진의 시간과 위치 정보를 분석하여\n자동으로 여행 타임라인을 만들어 드려요")
                    .wanderBodySecondary()
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Next Button
            Button(action: {
                withAnimation {
                    currentPage = 1
                }
            }) {
                Text("다음")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
        }
    }
}

#Preview {
    OnboardingIntroView(currentPage: .constant(0))
}
