import SwiftUI

// MARK: - P2P Share Complete View

/// 공유 링크 생성 완료 화면
struct P2PShareCompleteView: View {
    @Environment(\.dismiss) private var dismiss

    let shareResult: P2PShareResult
    let onDismiss: () -> Void

    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space7) {
                Spacer()

                // 성공 아이콘
                successIcon

                // 정보
                infoSection

                Spacer()

                // 공유 버튼들
                shareButtons
            }
            .padding()
            .navigationTitle("공유 준비 완료")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        onDismiss()
                    }
                }
            }
            .overlay {
                if showCopiedToast {
                    copiedToast
                }
            }
        }
    }

    // MARK: - Success Icon

    private var successIcon: some View {
        VStack(spacing: WanderSpacing.space4) {
            ZStack {
                Circle()
                    .fill(WanderColors.successBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(WanderColors.success)
            }

            Text("링크가 생성되었습니다")
                .font(WanderTypography.title2)
                .foregroundStyle(WanderColors.textPrimary)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: WanderSpacing.space4) {
            // 만료 정보
            if let expiresAt = shareResult.expiresAt {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(WanderColors.textSecondary)

                    Text("만료: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(WanderTypography.bodySmall)
                        .foregroundStyle(WanderColors.textSecondary)
                }
            } else {
                HStack {
                    Image(systemName: "infinity")
                        .foregroundStyle(WanderColors.textSecondary)

                    Text("만료 없음 (영구)")
                        .font(WanderTypography.bodySmall)
                        .foregroundStyle(WanderColors.textSecondary)
                }
            }

            // 사진 수
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundStyle(WanderColors.textSecondary)

                Text("\(shareResult.photoCount)장의 사진 포함")
                    .font(WanderTypography.bodySmall)
                    .foregroundStyle(WanderColors.textSecondary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    // MARK: - Share Buttons

    private var shareButtons: some View {
        VStack(spacing: WanderSpacing.space3) {
            // 시스템 공유 시트
            Button {
                shareViaSystemSheet()
            } label: {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
                .font(WanderTypography.headline)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
            }

            // 링크 복사
            Button {
                copyLinkToClipboard()
            } label: {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "doc.on.doc")
                    Text("링크 복사")
                }
                .font(WanderTypography.headline)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.surface)
                .foregroundStyle(WanderColors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
            }
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WanderColors.success)
                Text("링크가 복사되었습니다")
                    .font(WanderTypography.bodySmall)
            }
            .padding(WanderSpacing.space4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func shareViaSystemSheet() {
        let shareText = "Wander에서 여행 기록을 공유합니다!\n\(shareResult.shareURL.absoluteString)"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        // 현재 표시 중인 가장 상위 뷰 컨트롤러 찾기
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad 지원
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.maxY - 100,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = .down
        }

        topVC.present(activityVC, animated: true)
    }

    private func copyLinkToClipboard() {
        UIPasteboard.general.string = shareResult.shareURL.absoluteString

        withAnimation {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}
