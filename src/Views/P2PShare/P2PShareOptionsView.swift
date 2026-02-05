import SwiftUI

// MARK: - P2P Share Options View

/// P2P 공유 옵션 설정 화면
struct P2PShareOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var shareService = P2PShareService.shared

    let record: TravelRecord
    let onShareComplete: (P2PShareResult) -> Void

    @State private var photoQuality: PhotoQuality = .optimized
    @State private var linkExpiration: LinkExpiration = .sevenDays
    @State private var senderName: String = ""
    @State private var isCreatingLink = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // 헤더
                    headerSection

                    // 사진 품질 옵션
                    photoQualitySection

                    // 링크 만료 옵션
                    expirationSection

                    // 보내는 사람 이름 (선택)
                    senderNameSection

                    // 에러 메시지
                    if let error = errorMessage {
                        errorView(error)
                    }

                    // 링크 생성 버튼
                    createLinkButton
                }
                .padding()
            }
            .navigationTitle("Wander 공유")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .disabled(isCreatingLink)
            .overlay {
                if isCreatingLink {
                    loadingOverlay
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: WanderSpacing.iconHuge))
                .foregroundStyle(WanderColors.primary)

            Text(record.title)
                .font(WanderTypography.headline)
                .foregroundStyle(WanderColors.textPrimary)

            Text("\(record.photoCount)장의 사진")
                .font(WanderTypography.bodySmall)
                .foregroundStyle(WanderColors.textSecondary)
        }
        .padding(.vertical)
    }

    // MARK: - Photo Quality Section

    private var photoQualitySection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Label("사진 품질", systemImage: "photo")
                .font(WanderTypography.headline)
                .foregroundStyle(WanderColors.textPrimary)

            VStack(spacing: WanderSpacing.space2) {
                ForEach(PhotoQuality.allCases) { quality in
                    qualityOptionRow(quality)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    private func qualityOptionRow(_ quality: PhotoQuality) -> some View {
        Button {
            photoQuality = quality
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                    HStack {
                        Text(quality.displayName)
                            .font(WanderTypography.bodySmall)
                            .fontWeight(.medium)
                            .foregroundStyle(WanderColors.textPrimary)

                        if quality == .optimized {
                            Text("추천")
                                .font(WanderTypography.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WanderColors.primary.opacity(0.2))
                                .foregroundStyle(WanderColors.primary)
                                .clipShape(Capsule())
                        }
                    }

                    Text(quality.description)
                        .font(WanderTypography.caption1)
                        .foregroundStyle(WanderColors.textSecondary)
                }

                Spacer()

                Image(systemName: photoQuality == quality ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(photoQuality == quality ? WanderColors.primary : WanderColors.textTertiary)
            }
            .padding(.vertical, WanderSpacing.space2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expiration Section

    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Label("링크 만료", systemImage: "clock")
                .font(WanderTypography.headline)
                .foregroundStyle(WanderColors.textPrimary)

            HStack(spacing: WanderSpacing.space2) {
                ForEach(LinkExpiration.allCases) { expiration in
                    expirationButton(expiration)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    private func expirationButton(_ expiration: LinkExpiration) -> some View {
        Button {
            linkExpiration = expiration
        } label: {
            Text(expiration.displayName)
                .font(WanderTypography.bodySmall)
                .fontWeight(linkExpiration == expiration ? .semibold : .regular)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space2)
                .frame(maxWidth: .infinity)
                .background(
                    linkExpiration == expiration
                        ? WanderColors.primary
                        : WanderColors.border
                )
                .foregroundStyle(
                    linkExpiration == expiration ? .white : WanderColors.textPrimary
                )
                .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sender Name Section

    private var senderNameSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Label("보내는 사람 (선택)", systemImage: "person")
                .font(WanderTypography.headline)
                .foregroundStyle(WanderColors.textPrimary)

            TextField("이름 입력", text: $senderName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("받는 사람에게 표시됩니다")
                .font(WanderTypography.caption1)
                .foregroundStyle(WanderColors.textSecondary)
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(WanderColors.warning)

            Text(message)
                .font(WanderTypography.bodySmall)
                .foregroundStyle(WanderColors.textSecondary)
        }
        .padding(WanderSpacing.space4)
        .frame(maxWidth: .infinity)
        .background(WanderColors.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium))
    }

    // MARK: - Create Link Button

    private var createLinkButton: some View {
        Button {
            createShareLink()
        } label: {
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "link")
                Text("공유 링크 생성")
            }
            .font(WanderTypography.headline)
            .frame(maxWidth: .infinity)
            .frame(height: WanderSpacing.buttonHeight)
            .background(WanderColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
        }
        .disabled(isCreatingLink)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: WanderSpacing.space4) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(shareService.progressMessage)
                    .font(WanderTypography.bodySmall)
                    .foregroundStyle(.white)

                if shareService.progress > 0 {
                    ProgressView(value: shareService.progress)
                        .tint(.white)
                        .frame(width: 200)
                }
            }
            .padding(WanderSpacing.space7)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusXL))
        }
    }

    // MARK: - Actions

    private func createShareLink() {
        isCreatingLink = true
        errorMessage = nil

        Task {
            do {
                let options = ShareOptions(
                    photoQuality: photoQuality,
                    linkExpiration: linkExpiration,
                    senderName: senderName.isEmpty ? nil : senderName
                )

                let result = try await shareService.createShareLink(
                    for: record,
                    options: options
                )

                await MainActor.run {
                    isCreatingLink = false
                    onShareComplete(result)
                }

            } catch {
                await MainActor.run {
                    isCreatingLink = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
