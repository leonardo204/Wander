import SwiftUI
import SwiftData
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "DKImagePickerView")

/// DKImagePickerController를 사용한 사진 선택 화면 (날짜 필터 포함)
struct DKImagePickerView: View {
    // MARK: - Properties

    var onSaveComplete: ((TravelRecord) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 날짜 필터 상태
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var quickSelect: QuickSelectRange = .thisMonth
    @State private var showDatePicker = false

    // 선택된 사진
    @State private var selectedAssets: [PHAsset] = []

    // 분석 화면 표시
    @State private var showAnalysis = false

    // Picker 식별자 (날짜 변경 시 재생성용)
    @State private var pickerKey = UUID()

    // MARK: - Computed Properties

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: endDate))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 날짜 범위 선택
                dateRangeSection

                // Quick Select 칩
                quickSelectSection

                // DKImagePicker
                DKImagePickerRepresentable(
                    startDate: startDate,
                    endDate: endDate,
                    onSelect: { assets in
                        logger.info("📷 [DKImagePickerView] 사진 선택됨: \(assets.count)장")
                        selectedAssets = assets
                        if !assets.isEmpty {
                            showAnalysis = true
                        }
                    },
                    onCancel: {
                        logger.info("📷 [DKImagePickerView] 사진 선택 취소")
                        dismiss()
                    }
                )
                .id(pickerKey)  // 날짜 변경 시 재생성
            }
            .background(WanderColors.background)
            .navigationTitle("사진 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(WanderColors.textSecondary)
                }
            }
            .onAppear {
                logger.info("📷 [DKImagePickerView] 나타남")
            }
            .sheet(isPresented: $showDatePicker) {
                DateRangePickerSheet(
                    startDate: $startDate,
                    endDate: $endDate,
                    onApply: {
                        quickSelect = .custom
                        refreshPicker()
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showAnalysis) {
                AnalyzingViewWrapper(
                    selectedAssets: selectedAssets,
                    onSaveComplete: { savedRecord in
                        logger.info("📷 [DKImagePickerView] 저장 완료: \(savedRecord.title)")
                        onSaveComplete?(savedRecord)
                        dismiss()
                    }
                )
            }
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        Button(action: { showDatePicker = true }) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(WanderColors.primary)

                Text(dateRangeText)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
        }
    }

    // MARK: - Quick Select Section

    private var quickSelectSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WanderSpacing.space2) {
                QuickSelectChip(title: "오늘", isSelected: quickSelect == .today) {
                    selectQuickRange(.today)
                }
                QuickSelectChip(title: "이번 주", isSelected: quickSelect == .thisWeek) {
                    selectQuickRange(.thisWeek)
                }
                QuickSelectChip(title: "이번 달", isSelected: quickSelect == .thisMonth) {
                    selectQuickRange(.thisMonth)
                }
                QuickSelectChip(title: "최근 3개월", isSelected: quickSelect == .last3Months) {
                    selectQuickRange(.last3Months)
                }
                QuickSelectChip(title: "전체", isSelected: quickSelect == .all) {
                    selectQuickRange(.all)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space3)
        }
        .background(WanderColors.background)
    }

    // MARK: - Quick Select Logic

    private func selectQuickRange(_ range: QuickSelectRange) {
        quickSelect = range
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .today:
            startDate = calendar.startOfDay(for: now)
            endDate = now

        case .thisWeek:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            startDate = weekStart
            endDate = now

        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            startDate = monthStart
            endDate = now

        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now)!
            endDate = now

        case .all:
            startDate = calendar.date(byAdding: .year, value: -10, to: now)!
            endDate = now

        case .custom:
            break
        }

        refreshPicker()
        logger.info("📷 [DKImagePickerView] 기간 변경: \(range) - \(startDate) ~ \(endDate)")
    }

    private func refreshPicker() {
        // Picker 재생성으로 날짜 필터 적용
        pickerKey = UUID()
    }
}

// MARK: - AnalyzingViewWrapper

/// PhotoSelectionViewModel 없이 PHAsset 배열로 직접 분석 시작하는 래퍼
struct AnalyzingViewWrapper: View {
    let selectedAssets: [PHAsset]
    var onSaveComplete: ((TravelRecord) -> Void)?

    @StateObject private var viewModel: PhotoSelectionViewModel

    init(selectedAssets: [PHAsset], onSaveComplete: ((TravelRecord) -> Void)?) {
        self.selectedAssets = selectedAssets
        self.onSaveComplete = onSaveComplete

        let vm = PhotoSelectionViewModel()
        vm.selectedAssets = selectedAssets
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        AnalyzingView(viewModel: viewModel, onSaveComplete: onSaveComplete)
    }
}

// MARK: - Preview

#Preview {
    DKImagePickerView()
}
