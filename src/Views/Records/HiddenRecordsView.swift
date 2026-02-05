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

    @State private var authManager = AuthenticationManager.shared
    @State private var showPINInput = false
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: TravelRecord?

    /// 인증 상태
    private var isAuthenticated: Bool {
        authManager.isAuthenticationValid
    }

    /// PIN 설정 여부
    private var isPINSet: Bool {
        authManager.isPINSet
    }

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
                attemptAuthentication()
            }
            .sheet(isPresented: $showPINInput) {
                NavigationStack {
                    PINInputView(mode: .verify, onSuccess: {
                        showPINInput = false
                        logger.info("✅ [HiddenRecordsView] PIN 인증 성공")
                    }, onCancel: {
                        showPINInput = false
                        dismiss()
                    })
                    .navigationTitle("PIN 입력")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    // MARK: - Authentication View
    private var authenticationView: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            Image(systemName: isPINSet ? "lock.shield.fill" : "lock.open.fill")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.primary)

            VStack(spacing: WanderSpacing.space2) {
                Text(isPINSet ? "인증이 필요합니다" : "보안 설정 필요")
                    .font(WanderTypography.title2)
                    .foregroundColor(WanderColors.textPrimary)

                Text(isPINSet ? "숨긴 기록을 보려면 인증해 주세요" : "설정에서 PIN을 설정해 주세요")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            if isPINSet {
                Button(action: { attemptAuthentication() }) {
                    HStack(spacing: WanderSpacing.space2) {
                        Image(systemName: authManager.canUseBiometric && authManager.isBiometricEnabled ? authManager.biometricIcon : "lock.fill")
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
            } else {
                // PIN 미설정 시 설정 안내
                Button(action: { dismiss() }) {
                    Text("설정으로 이동")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(WanderColors.primaryPale)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }
                .padding(.horizontal, WanderSpacing.space8)
            }

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
    private func attemptAuthentication() {
        // 이미 인증된 상태면 스킵
        if authManager.isAuthenticationValid {
            logger.info("✅ [HiddenRecordsView] 기존 인증 유효")
            return
        }

        // PIN이 설정되지 않은 경우
        guard isPINSet else {
            logger.info("ℹ️ [HiddenRecordsView] PIN 미설정")
            return
        }

        // 생체인증 시도
        if authManager.canUseBiometric && authManager.isBiometricEnabled {
            Task {
                let success = await authManager.authenticateWithBiometric()
                if !success {
                    // 생체인증 실패 시 PIN 입력 화면 표시
                    await MainActor.run {
                        showPINInput = true
                    }
                }
            }
        } else {
            // PIN 입력 화면 표시
            showPINInput = true
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

                RecordCategoryBadge(category: record.category)
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
        // 같은 날이면 하나만 표시
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }
}

#Preview {
    HiddenRecordsView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
