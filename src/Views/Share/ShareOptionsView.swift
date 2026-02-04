import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareOptionsView")

// MARK: - 공유 대상 선택 뷰

/// 공유 대상(일반/Instagram Feed/Instagram Story)을 선택하는 뷰
struct ShareOptionsView: View {
    @Binding var selectedDestination: ShareDestination
    let isInstagramInstalled: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: WanderSpacing.space6) {
                    // 헤더
                    VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                        Text("어디에 공유할까요?")
                            .font(WanderTypography.title2)
                            .foregroundColor(WanderColors.textPrimary)

                        Text("공유할 대상을 선택하세요")
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                    .padding(.top, WanderSpacing.space4)

                    // 공유 대상 카드들
                    VStack(spacing: WanderSpacing.space3) {
                        // 일반 공유
                        ShareDestinationCard(
                            destination: .general,
                            isSelected: selectedDestination == .general,
                            subtitle: "메시지, 카카오톡, 저장 등"
                        ) {
                            selectedDestination = .general
                        }

                        // Instagram Feed
                        ShareDestinationCard(
                            destination: .instagramFeed,
                            isSelected: selectedDestination == .instagramFeed,
                            subtitle: "4:5 비율 피드 게시물",
                            isDisabled: !isInstagramInstalled,
                            disabledMessage: "Instagram 미설치"
                        ) {
                            if isInstagramInstalled {
                                selectedDestination = .instagramFeed
                            }
                        }

                        // Instagram Story
                        ShareDestinationCard(
                            destination: .instagramStory,
                            isSelected: selectedDestination == .instagramStory,
                            subtitle: "9:16 비율 스토리",
                            isDisabled: !isInstagramInstalled,
                            disabledMessage: "Instagram 미설치"
                        ) {
                            if isInstagramInstalled {
                                selectedDestination = .instagramStory
                            }
                        }
                    }

                    // Instagram 안내
                    if selectedDestination == .instagramFeed {
                        InstagramInfoBanner(
                            title: "캡션은 클립보드에 복사됩니다",
                            message: "Instagram에서 캡션 입력란에 붙여넣기 해주세요."
                        )
                    }
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.bottom, WanderSpacing.space8)
            }

            // 다음 버튼
            VStack(spacing: 0) {
                Divider()
                    .foregroundColor(WanderColors.border)

                Button(action: onNext) {
                    Text("다음")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
            .background(WanderColors.surface)
        }
    }
}

// MARK: - 공유 대상 카드

private struct ShareDestinationCard: View {
    let destination: ShareDestination
    let isSelected: Bool
    let subtitle: String
    var isDisabled: Bool = false
    var disabledMessage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WanderSpacing.space4) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(isSelected ? WanderColors.primary : WanderColors.primaryPale)
                        .frame(width: 48, height: 48)

                    Image(systemName: destination.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : WanderColors.primary)
                }

                // 텍스트
                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.displayName)
                        .font(WanderTypography.headline)
                        .foregroundColor(isDisabled ? WanderColors.textTertiary : WanderColors.textPrimary)

                    if isDisabled, let message = disabledMessage {
                        Text(message)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.error)
                    } else {
                        Text(subtitle)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                }

                Spacer()

                // 선택 표시
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.primary)
                } else if isDisabled {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.textTertiary)
                } else {
                    Circle()
                        .strokeBorder(WanderColors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(WanderSpacing.space4)
            .background(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                    .fill(WanderColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                            .strokeBorder(
                                isSelected ? WanderColors.primary : WanderColors.border,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Instagram 안내 배너

private struct InstagramInfoBanner: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space3) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(WanderColors.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WanderTypography.bodySmall)
                    .foregroundColor(WanderColors.textPrimary)

                Text(message)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.primaryPale)
        .cornerRadius(WanderSpacing.radiusMedium)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ShareOptionsView(
            selectedDestination: .constant(.general),
            isInstagramInstalled: true
        ) {
            print("Next tapped")
        }
    }
}

#Preview("Instagram 미설치") {
    NavigationStack {
        ShareOptionsView(
            selectedDestination: .constant(.general),
            isInstagramInstalled: false
        ) {
            print("Next tapped")
        }
    }
}
