import SwiftUI

struct OnboardingContainerView: View {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                OnboardingIntroView(currentPage: $currentPage)
                    .tag(0)

                OnboardingPhotoView(currentPage: $currentPage)
                    .tag(1)

                OnboardingLocationView(isOnboardingCompleted: $isOnboardingCompleted)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page Indicator
            HStack(spacing: WanderSpacing.space2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == currentPage ? WanderColors.primary : WanderColors.border)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, WanderSpacing.space6)
        }
        .background(WanderColors.background)
    }
}

#Preview {
    OnboardingContainerView()
}
