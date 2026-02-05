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
            VStack(spacing: 32) {
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(WanderColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(WanderColors.success)
            }

            Text("링크가 생성되었습니다")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 16) {
            // 만료 정보
            if let expiresAt = shareResult.expiresAt {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)

                    Text("만료: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "infinity")
                        .foregroundStyle(.secondary)

                    Text("만료 없음 (영구)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // 사진 수
            HStack {
                Image(systemName: "photo.stack")
                    .foregroundStyle(.secondary)

                Text("\(shareResult.photoCount)장의 사진 포함")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Share Buttons

    private var shareButtons: some View {
        VStack(spacing: 12) {
            // 시스템 공유 시트
            Button {
                shareViaSystemSheet()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(WanderColors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 링크 복사
            Button {
                copyLinkToClipboard()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("링크 복사")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("링크가 복사되었습니다")
            }
            .padding()
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
