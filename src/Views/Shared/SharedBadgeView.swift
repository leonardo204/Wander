import SwiftUI

// MARK: - Shared Badge View

/// 공유받은 기록 표시 배지 ("공유됨" 고정 배지)
struct SharedBadgeView: View {
    var size: BadgeSize = .medium

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

    /// 공유 배지 색상 - 청록색
    private static let sharedColor = Color(red: 0.2, green: 0.6, blue: 0.7)  // #339CB3

    var body: some View {
        HStack(spacing: WanderSpacing.space1) {
            Image(systemName: "link")
                .font(.system(size: size.iconSize, weight: .bold))

            Text("공유됨")
                .font(size.fontSize)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            LinearGradient(
                colors: [Self.sharedColor, Self.sharedColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Self.sharedColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Expiration Badge View

/// 만료일 D-day 표시 배지 (공유됨 배지와 함께 사용)
struct ExpirationBadgeView: View {
    let expirationStatus: ShareExpirationStatus
    var size: SharedBadgeView.BadgeSize = .medium

    // MARK: - Colors

    /// 여유 색상 - 청록색 (D-4+)
    private static let normalColor = Color(red: 0.2, green: 0.6, blue: 0.7)  // #339CB3

    /// 주의 색상 - 주황색 (D-3 이하)
    private static let warningColor = Color(red: 0.95, green: 0.6, blue: 0.2)  // #F29933

    /// 긴급 색상 - 빨강색 (오늘 만료)
    private static let urgentColor = Color(red: 0.9, green: 0.3, blue: 0.3)  // #E64D4D

    // MARK: - Computed Properties

    private var badgeColor: Color {
        switch expirationStatus {
        case .notShared, .permanent:
            return Self.normalColor
        case .normal:
            return Self.normalColor
        case .soon:
            return Self.warningColor
        case .today, .expired:
            return Self.urgentColor
        }
    }

    private var badgeText: String {
        switch expirationStatus {
        case .notShared, .permanent:
            return ""
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

    private var shouldShow: Bool {
        switch expirationStatus {
        case .notShared, .permanent:
            return false
        default:
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        if shouldShow {
            Text(badgeText)
                .font(size.fontSize)
                .fontWeight(.semibold)
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
}

// MARK: - Combined Share Status View

/// 공유 상태 뷰 - "공유됨" + "D-day" 배지 조합
struct ShareStatusBadgesView: View {
    let expirationStatus: ShareExpirationStatus
    var size: SharedBadgeView.BadgeSize = .medium

    var body: some View {
        HStack(spacing: 4) {
            SharedBadgeView(size: size)
            ExpirationBadgeView(expirationStatus: expirationStatus, size: size)
        }
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
                ShareStatusBadgesView(expirationStatus: expirationStatus, size: .small)
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
        }
    }
}

// MARK: - Preview

#Preview("Badge Combinations") {
    VStack(spacing: 16) {
        // 영구 보관 - D-day 배지 없음
        ShareStatusBadgesView(expirationStatus: .permanent)

        // 여유 있음
        ShareStatusBadgesView(expirationStatus: .normal(days: 7))
        ShareStatusBadgesView(expirationStatus: .normal(days: 5))

        // 곧 만료
        ShareStatusBadgesView(expirationStatus: .soon(days: 3))
        ShareStatusBadgesView(expirationStatus: .soon(days: 1))

        // 오늘/만료
        ShareStatusBadgesView(expirationStatus: .today)
        ShareStatusBadgesView(expirationStatus: .expired)
    }
    .padding()
}

#Preview("Badge Sizes") {
    VStack(spacing: 20) {
        ShareStatusBadgesView(expirationStatus: .normal(days: 5), size: .small)
        ShareStatusBadgesView(expirationStatus: .normal(days: 5), size: .medium)
        ShareStatusBadgesView(expirationStatus: .normal(days: 5), size: .large)
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
