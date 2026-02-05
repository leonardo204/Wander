import SwiftUI

// MARK: - Shared Badge View

/// 공유받은 기록 표시 배지 (만료일 D-day 포함)
struct SharedBadgeView: View {
    var size: BadgeSize = .medium
    var expirationStatus: ShareExpirationStatus = .permanent

    enum BadgeSize {
        case small   // 리스트 썸네일용
        case medium  // 카드용
        case large   // 상세 화면용

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return WanderTypography.caption2
            case .medium: return WanderTypography.caption1
            case .large: return WanderTypography.footnote
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 2, leading: WanderSpacing.space1, bottom: 2, trailing: WanderSpacing.space1)
            case .medium:
                return EdgeInsets(top: WanderSpacing.space1, leading: 6, bottom: WanderSpacing.space1, trailing: 6)
            case .large:
                return EdgeInsets(top: 6, leading: WanderSpacing.space2, bottom: 6, trailing: WanderSpacing.space2)
            }
        }
    }

    // MARK: - Colors

    /// 기본 색상 - 청록색 (여유 있음)
    private static let normalColor = Color(red: 0.2, green: 0.6, blue: 0.7)  // #339CB3

    /// 주의 색상 - 주황색 (곧 만료, D-3 이하)
    private static let warningColor = Color(red: 0.95, green: 0.6, blue: 0.2)  // #F29933

    /// 긴급 색상 - 빨강색 (오늘 만료)
    private static let urgentColor = Color(red: 0.9, green: 0.3, blue: 0.3)  // #E64D4D

    /// 영구 색상 - 보라색 (영구 보관)
    private static let permanentColor = Color(red: 0.5, green: 0.4, blue: 0.7)  // #8066B3

    // MARK: - Computed Properties

    private var badgeColor: Color {
        switch expirationStatus {
        case .notShared:
            return Self.normalColor
        case .permanent:
            return Self.permanentColor
        case .normal:
            return Self.normalColor
        case .soon:
            return Self.warningColor
        case .today:
            return Self.urgentColor
        case .expired:
            return Self.urgentColor
        }
    }

    private var badgeText: String {
        switch expirationStatus {
        case .notShared:
            return "공유됨"
        case .permanent:
            return "공유됨"
        case .normal(let days):
            return "D-\(days)"
        case .soon(let days):
            return "D-\(days)"
        case .today:
            return "오늘 만료"
        case .expired:
            return "만료됨"
        }
    }

    private var badgeIcon: String {
        switch expirationStatus {
        case .permanent:
            return "infinity"
        case .today, .expired:
            return "exclamationmark.circle"
        default:
            return "link"
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: WanderSpacing.space1) {
            Image(systemName: badgeIcon)
                .font(.system(size: size.iconSize, weight: .bold))

            Text(badgeText)
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            LinearGradient(
                colors: [badgeColor, badgeColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shared From View

/// 공유자 정보 표시 뷰
struct SharedFromView: View {
    let senderName: String?
    let sharedAt: Date?
    var expirationStatus: ShareExpirationStatus = .permanent

    var body: some View {
        if let sender = senderName {
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "person.circle")
                    .foregroundStyle(WanderColors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sender)님이 공유")
                        .font(WanderTypography.bodySmall)
                        .foregroundStyle(WanderColors.textPrimary)

                    if let date = sharedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(WanderTypography.caption1)
                            .foregroundStyle(WanderColors.textSecondary)
                    }
                }

                Spacer()

                // 만료 상태 배지
                SharedBadgeView(size: .small, expirationStatus: expirationStatus)
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
        }
    }
}

// MARK: - Preview

#Preview("Badge - Normal") {
    VStack(spacing: 16) {
        SharedBadgeView(size: .medium, expirationStatus: .permanent)
        SharedBadgeView(size: .medium, expirationStatus: .normal(days: 7))
        SharedBadgeView(size: .medium, expirationStatus: .normal(days: 5))
        SharedBadgeView(size: .medium, expirationStatus: .soon(days: 3))
        SharedBadgeView(size: .medium, expirationStatus: .soon(days: 1))
        SharedBadgeView(size: .medium, expirationStatus: .today)
        SharedBadgeView(size: .medium, expirationStatus: .expired)
    }
    .padding()
}

#Preview("Badge Sizes") {
    VStack(spacing: 20) {
        SharedBadgeView(size: .small, expirationStatus: .normal(days: 5))
        SharedBadgeView(size: .medium, expirationStatus: .normal(days: 5))
        SharedBadgeView(size: .large, expirationStatus: .normal(days: 5))
    }
    .padding()
}

#Preview("Shared From") {
    SharedFromView(
        senderName: "홍길동",
        sharedAt: Date(),
        expirationStatus: .soon(days: 2)
    )
    .padding()
}
