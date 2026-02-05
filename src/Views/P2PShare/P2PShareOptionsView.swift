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
                VStack(spacing: 24) {
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
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(WanderColors.primary)

            Text(record.title)
                .font(.headline)

            Text("\(record.photoCount)장의 사진")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }

    // MARK: - Photo Quality Section

    private var photoQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("사진 품질", systemImage: "photo")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(PhotoQuality.allCases) { quality in
                    qualityOptionRow(quality)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func qualityOptionRow(_ quality: PhotoQuality) -> some View {
        Button {
            photoQuality = quality
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quality.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if quality == .optimized {
                            Text("추천")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(WanderColors.primary.opacity(0.2))
                                .foregroundStyle(WanderColors.primary)
                                .clipShape(Capsule())
                        }
                    }

                    Text(quality.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: photoQuality == quality ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(photoQuality == quality ? WanderColors.primary : .secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expiration Section

    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("링크 만료", systemImage: "clock")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(LinkExpiration.allCases) { expiration in
                    expirationButton(expiration)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func expirationButton(_ expiration: LinkExpiration) -> some View {
        Button {
            linkExpiration = expiration
        } label: {
            Text(expiration.displayName)
                .font(.subheadline)
                .fontWeight(linkExpiration == expiration ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    linkExpiration == expiration
                        ? WanderColors.primary
                        : Color(.systemGray5)
                )
                .foregroundStyle(
                    linkExpiration == expiration ? .white : .primary
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sender Name Section

    private var senderNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("보내는 사람 (선택)", systemImage: "person")
                .font(.headline)

            TextField("이름 입력", text: $senderName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Text("받는 사람에게 표시됩니다")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Create Link Button

    private var createLinkButton: some View {
        Button {
            createShareLink()
        } label: {
            HStack {
                Image(systemName: "link")
                Text("공유 링크 생성")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(WanderColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isCreatingLink)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(shareService.progressMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white)

                if shareService.progress > 0 {
                    ProgressView(value: shareService.progress)
                        .tint(.white)
                        .frame(width: 200)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
