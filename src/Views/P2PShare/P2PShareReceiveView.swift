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
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("공유 정보를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await loadPreview()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("다시 시도")
                }
                .padding()
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    // MARK: - Preview Content

    private func previewContent(_ preview: SharePreview) -> some View {
        ScrollView {
            VStack(spacing: 24) {
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
            .padding()
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .overlay {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    // MARK: - Info Section

    private func infoSection(_ preview: SharePreview) -> some View {
        VStack(spacing: 12) {
            Text(preview.title)
                .font(.title2)
                .fontWeight(.bold)

            Text(formatDateRange(start: preview.startDate, end: preview.endDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("\(preview.placeCount)곳", systemImage: "mappin.and.ellipse")
                Label(formatDistance(preview.totalDistance), systemImage: "car")
                Label("\(preview.photoCount)장", systemImage: "photo")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sender Section

    private func senderSection(_ sender: String) -> some View {
        HStack {
            Image(systemName: "person.circle")
                .font(.title2)
                .foregroundStyle(WanderColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("공유자")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(sender)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Expiration Section

    private func expirationSection(_ preview: SharePreview) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)

            if let expiresAt = preview.expiresAt {
                Text("만료: \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("만료 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveRecord()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("내 기록에 저장")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(WanderColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSaving)
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
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
