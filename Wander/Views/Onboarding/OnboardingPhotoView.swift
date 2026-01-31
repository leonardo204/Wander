import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "OnboardingPhoto")

struct OnboardingPhotoView: View {
    @Binding var currentPage: Int
    @State private var permissionStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            // Illustration
            Image(systemName: "photo.stack")
                .font(.system(size: 80))
                .foregroundColor(WanderColors.primary)

            VStack(spacing: WanderSpacing.space3) {
                Text("사진 접근 권한이 필요해요")
                    .wanderTitle1()
                    .multilineTextAlignment(.center)

                Text("촬영 시간과 위치 정보를 분석하기 위해\n사진 라이브러리에 접근해야 해요\n\n모든 처리는 기기 내에서만 이루어져요")
                    .wanderBodySecondary()
                    .multilineTextAlignment(.center)
            }

            // Privacy Badge
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(WanderColors.success)
                Text("100% 온디바이스 처리")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.success)
            }
            .padding(.horizontal, WanderSpacing.space4)
            .padding(.vertical, WanderSpacing.space2)
            .background(WanderColors.successBackground)
            .cornerRadius(WanderSpacing.radiusMedium)

            Spacer()

            VStack(spacing: WanderSpacing.space3) {
                // Allow Button
                Button(action: {
                    requestPhotoPermission()
                }) {
                    Text("사진 접근 허용하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }

                // Skip Button
                Button(action: {
                    withAnimation {
                        currentPage = 2
                    }
                }) {
                    Text("나중에 설정하기")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
        }
    }

    private func requestPhotoPermission() {
        logger.info("📷 [OnboardingPhoto] 사진 권한 요청")
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                logger.info("📷 [OnboardingPhoto] 사진 권한 응답: \(String(describing: status))")
                permissionStatus = status
                withAnimation {
                    currentPage = 2
                }
            }
        }
    }
}

#Preview {
    OnboardingPhotoView(currentPage: .constant(1))
}
