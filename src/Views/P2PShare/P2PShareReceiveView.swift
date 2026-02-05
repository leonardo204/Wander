import SwiftUI
import SwiftData

// MARK: - P2P Share Receive View

/// 공유 기록 수신 화면
struct P2PShareReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var shareService = P2PShareService.shared

    let shareURL: URL
    let onSaveComplete: (TravelRecord) -> Void

    @State private var preview: SharePreview?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let preview = preview {
                    previewContent(preview)
                }
            }
            .navigationTitle("공유받은 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPreview()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            ProgressView()
                .scaleEffect(1.5)

            Text("공유 정보를 불러오는 중...")
                .font(WanderTypography.bodySmall)
                .foregroundStyle(WanderColors.textSecondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: WanderSpacing.space6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(WanderColors.warning)

            Text(message)
                .font(WanderTypography.headline)
                .foregroundStyle(WanderColors.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadPreview()
                }
            } label: {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "arrow.clockwise")
                    Text("다시 시도")
                }
                .font(WanderTypography.headline)
                .frame(height: WanderSpacing.buttonHeight)
                .padding(.horizontal, WanderSpacing.space6)
                .background(WanderColors.surface)
                .foregroundStyle(WanderColors.textPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
            }
        }
        .padding(WanderSpacing.space4)
    }

    // MARK: - Preview Content

    private func previewContent(_ preview: SharePreview) -> some View {
        ScrollView {
            VStack(spacing: WanderSpacing.space6) {
                // 썸네일
                thumbnailView(preview)

                // 정보
                infoSection(preview)

                // 공유자 정보
                if let sender = preview.senderName {
                    senderSection(sender)
                }

                // 만료 정보
                expirationSection(preview)

                // 저장 버튼
                saveButton
            }
            .padding(WanderSpacing.space4)
        }
        .overlay {
            if isSaving {
                savingOverlay
            }
        }
    }

    // MARK: - Thumbnail View

    private func thumbnailView(_ preview: SharePreview) -> some View {
        Group {
            if let thumbnailData = preview.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusXL))
            } else {
                RoundedRectangle(cornerRadius: WanderSpacing.radiusXL)
                    .fill(WanderColors.surface)
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.system(size: WanderSpacing.iconHuge))
                            .foregroundStyle(WanderColors.textSecondary)
                    }
            }
        }
    }

    // MARK: - Info Section

    private func infoSection(_ preview: SharePreview) -> some View {
        VStack(spacing: WanderSpacing.space3) {
            Text(preview.title)
                .font(WanderTypography.title2)
                .foregroundStyle(WanderColors.textPrimary)

            Text(formatDateRange(start: preview.startDate, end: preview.endDate))
                .font(WanderTypography.bodySmall)
                .foregroundStyle(WanderColors.textSecondary)

            HStack(spacing: WanderSpacing.space4) {
                Label("\(preview.placeCount)곳", systemImage: "mappin.and.ellipse")
                Label(formatDistance(preview.totalDistance), systemImage: "car")
                Label("\(preview.photoCount)장", systemImage: "photo")
            }
            .font(WanderTypography.bodySmall)
            .foregroundStyle(WanderColors.textSecondary)
        }
        .padding(WanderSpacing.space4)
        .frame(maxWidth: .infinity)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    // MARK: - Sender Section

    private func senderSection(_ sender: String) -> some View {
        HStack {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(WanderColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("공유자")
                    .font(WanderTypography.caption1)
                    .foregroundStyle(WanderColors.textSecondary)

                Text(sender)
                    .font(WanderTypography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(WanderColors.textPrimary)
            }

            Spacer()
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    // MARK: - Expiration Section

    private func expirationSection(_ preview: SharePreview) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(WanderColors.textSecondary)

            if let expiresAt = preview.expiresAt {
                Text("만료: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(WanderTypography.bodySmall)
                    .foregroundStyle(WanderColors.textSecondary)
            } else {
                Text("만료 없음")
                    .font(WanderTypography.bodySmall)
                    .foregroundStyle(WanderColors.textSecondary)
            }

            Spacer()
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveRecord()
        } label: {
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "square.and.arrow.down")
                Text("내 기록에 저장")
            }
            .font(WanderTypography.headline)
            .frame(maxWidth: .infinity)
            .frame(height: WanderSpacing.buttonHeight)
            .background(WanderColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
        }
        .disabled(isSaving)
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
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

    private func loadPreview() async {
        isLoading = true
        errorMessage = nil

        do {
            preview = try await shareService.receiveSharePreview(from: shareURL)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func saveRecord() {
        isSaving = true

        Task {
            do {
                let savedRecord = try await shareService.saveSharedRecord(
                    from: shareURL,
                    modelContext: modelContext
                )

                await MainActor.run {
                    isSaving = false
                    onSaveComplete(savedRecord)
                }

            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"

        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return "\(Int(meters))m"
        }
    }
}
