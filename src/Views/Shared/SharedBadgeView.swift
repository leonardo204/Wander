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
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .footnote
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .medium:
                return EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            case .large:
                return EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: size.iconSize, weight: .semibold))

            Text("공유됨")
                .font(size.fontSize)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            LinearGradient(
                colors: [WanderColors.primary, WanderColors.primary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Shared From View

/// 공유자 정보 표시 뷰
struct SharedFromView: View {
    let senderName: String?
    let sharedAt: Date?

    var body: some View {
        if let sender = senderName {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .foregroundStyle(WanderColors.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sender)님이 공유")
                        .font(.subheadline)

                    if let date = sharedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
