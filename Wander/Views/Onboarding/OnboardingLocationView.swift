import SwiftUI
import CoreLocation

struct OnboardingLocationView: View {
    @Binding var isOnboardingCompleted: Bool
    @StateObject private var locationManager = LocationPermissionManager()

    var body: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            // Illustration
            Image(systemName: "location.circle")
                .font(.system(size: 80))
                .foregroundColor(WanderColors.primary)

            VStack(spacing: WanderSpacing.space3) {
                Text("위치 권한이 필요해요")
                    .wanderTitle1()
                    .multilineTextAlignment(.center)

                Text("GPS 좌표를 주소로 변환하여\n장소 이름을 자동으로 표시해 드려요")
                    .wanderBodySecondary()
                    .multilineTextAlignment(.center)
            }

            // Info Badge
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "battery.100")
                    .foregroundColor(WanderColors.info)
                Text("앱 사용 중에만 위치 사용")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.info)
            }
            .padding(.horizontal, WanderSpacing.space4)
            .padding(.vertical, WanderSpacing.space2)
            .background(WanderColors.infoBackground)
            .cornerRadius(WanderSpacing.radiusMedium)

            Spacer()

            VStack(spacing: WanderSpacing.space3) {
                // Allow Button
                Button(action: {
                    locationManager.requestPermission()
                    completeOnboarding()
                }) {
                    Text("위치 접근 허용하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }

                // Skip Button
                Button(action: {
                    completeOnboarding()
                }) {
                    Text("위치 없이 계속하기")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
        }
    }

    private func completeOnboarding() {
        withAnimation {
            isOnboardingCompleted = true
        }
    }
}

// MARK: - Location Permission Manager
class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

#Preview {
    OnboardingLocationView(isOnboardingCompleted: .constant(false))
}
