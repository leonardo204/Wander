import SwiftUI

struct ResultStatsSection: View {
    let result: AnalysisResult

    var body: some View {
        VStack(spacing: WanderSpacing.space3) {
            // 분석 레벨 배지 (스마트 분석인 경우)
            if let badge = result.analysisLevelBadge {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: result.smartAnalysisResult?.analysisLevel == .advanced ? "brain" : "sparkles")
                        .font(.system(size: 14))
                    Text(badge)
                        .font(WanderTypography.caption1)

                    // 분석 통계
                    if let smart = result.smartAnalysisResult {
                        Text("·")
                        Text("장면 \(smart.visionClassificationCount)장 분석")
                            .font(WanderTypography.caption2)
                    }
                }
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space2)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)
            }

            // 기본 통계 카드
            HStack(spacing: WanderSpacing.space4) {
                StatCard(
                    icon: "mappin.circle.fill",
                    value: "\(result.placeCount)",
                    label: "방문 장소"
                )

                StatCard(
                    icon: "car.fill",
                    value: String(format: "%.1f", result.totalDistance),
                    label: "이동 거리 (km)"
                )

                StatCard(
                    icon: "photo.fill",
                    value: "\(result.photoCount)",
                    label: "사진"
                )
            }

            // 서브타이틀
            Text(result.subtitle)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: WanderSpacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(WanderColors.primary)

            Text(value)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(label)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}
