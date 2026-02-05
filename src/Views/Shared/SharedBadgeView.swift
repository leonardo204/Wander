import SwiftUI

// MARK: - Shared Badge View

/// 공유받은 기록 표시 배지
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

    /// 더 진한 청록색 - 공유 배지용
    private static let sharedBadgeColor = Color(red: 0.2, green: 0.6, blue: 0.7)  // #339CB3 계열

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
                colors: [Self.sharedBadgeColor, Self.sharedBadgeColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: Self.sharedBadgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shared From View

/// 공유자 정보 표시 뷰
struct SharedFromView: View {
    let senderName: String?
    let sharedAt: Date?

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
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
        }
    }
}

// MARK: - Preview

#Preview("Badge Sizes") {
    VStack(spacing: 20) {
        SharedBadgeView(size: .small)
        SharedBadgeView(size: .medium)
        SharedBadgeView(size: .large)
    }
    .padding()
}

#Preview("Shared From") {
    SharedFromView(
        senderName: "홍길동",
        sharedAt: Date()
    )
    .padding()
}
