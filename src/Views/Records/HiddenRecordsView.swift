import SwiftUI
import SwiftData
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "HiddenRecordsView")

/// 숨긴 기록 목록 화면 (인증 필요)
struct HiddenRecordsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TravelRecord> { $0.isHidden }, sort: \TravelRecord.createdAt, order: .reverse)
    private var hiddenRecords: [TravelRecord]

    @State private var isAuthenticated = false
    @State private var authError: String?
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: TravelRecord?

    var body: some View {
        NavigationStack {
            Group {
                if isAuthenticated {
                    authenticatedContent
                } else {
                    authenticationView
                }
            }
            .navigationTitle("숨긴 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                authenticate()
            }
        }
    }

    // MARK: - Authentication View
    private var authenticationView: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.primary)

            VStack(spacing: WanderSpacing.space2) {
                Text("인증이 필요합니다")
                    .font(WanderTypography.title2)
                    .foregroundColor(WanderColors.textPrimary)

                Text("숨긴 기록을 보려면 인증해 주세요")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            if let error = authError {
                Text(error)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.error)
                    .padding(.horizontal, WanderSpacing.space4)
                    .multilineTextAlignment(.center)
            }

            Button(action: { authenticate() }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "faceid")
                    Text("인증하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.horizontal, WanderSpacing.space8)

            Spacer()
        }
        .padding(WanderSpacing.screenMargin)
        .background(WanderColors.background)
    }

    // MARK: - Authenticated Content
    private var authenticatedContent: some View {
        Group {
            if hiddenRecords.isEmpty {
                emptyStateView
            } else {
                recordsList
            }
        }
        .background(WanderColors.background)
        .confirmationDialog(
            "이 기록을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let record = recordToDelete {
                    deleteRecord(record)
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제된 기록은 복구할 수 없습니다.")
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "eye.slash")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("숨긴 기록이 없습니다")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            Text("기록 목록에서 숨기기를 선택하면\n여기에 표시됩니다")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Records List
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: WanderSpacing.space4) {
                ForEach(hiddenRecords) { record in
                    NavigationLink(destination: RecordDetailFullView(record: record)) {
                        HiddenRecordCard(record: record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            unhideRecord(record)
                        } label: {
                            Label("숨김 해제", systemImage: "eye")
                        }

                        Button(role: .destructive) {
                            recordToDelete = record
                            showDeleteConfirmation = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space4)
        }
    }

    // MARK: - Authentication
    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "숨긴 기록을 보려면 인증이 필요합니다") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        logger.info("🔓 [HiddenRecordsView] 생체 인증 성공")
                        isAuthenticated = true
                        authError = nil
                    } else {
                        logger.warning("🔒 [HiddenRecordsView] 생체 인증 실패: \(authenticationError?.localizedDescription ?? "알 수 없음")")
                        // 생체 인증 실패 시 기기 암호로 대체
                        authenticateWithPasscode()
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            // 생체 인증 불가, 기기 암호로 대체
            authenticateWithPasscode()
        } else {
            // 인증 방법 없음 - 기기에 인증이 설정되지 않음
            logger.info("🔓 [HiddenRecordsView] 인증 방법 없음 - 접근 허용")
            isAuthenticated = true
        }
    }

    private func authenticateWithPasscode() {
        let context = LAContext()

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "숨긴 기록을 보려면 인증이 필요합니다") { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    logger.info("🔓 [HiddenRecordsView] 암호 인증 성공")
                    isAuthenticated = true
                    authError = nil
                } else {
                    logger.warning("🔒 [HiddenRecordsView] 암호 인증 실패")
                    authError = "인증에 실패했습니다. 다시 시도해 주세요."
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func unhideRecord(_ record: TravelRecord) {
        record.isHidden = false
        record.updatedAt = Date()
        try? modelContext.save()
        logger.info("👁️ [HiddenRecordsView] 기록 숨김 해제: \(record.title)")
    }

    private func deleteRecord(_ record: TravelRecord) {
        modelContext.delete(record)
        try? modelContext.save()
        recordToDelete = nil
        logger.info("🗑️ [HiddenRecordsView] 기록 삭제: \(record.title)")
    }
}

// MARK: - Hidden Record Card
struct HiddenRecordCard: View {
    let record: TravelRecord

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                // Hidden indicator
                Image(systemName: "eye.slash")
                    .font(.system(size: 14))
                    .foregroundColor(WanderColors.textTertiary)

                Spacer()

                RecordTypeBadge(type: record.recordType)
            }

            Text(record.title)
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text(formatDateRange(start: record.startDate, end: record.endDate))
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)

            HStack(spacing: WanderSpacing.space5) {
                StatBadge(icon: "mappin", value: "\(record.placeCount)곳")
                StatBadge(icon: "photo", value: "\(record.photoCount)장")
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                .stroke(WanderColors.border, lineWidth: 1)
        )
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}

#Preview {
    HiddenRecordsView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
