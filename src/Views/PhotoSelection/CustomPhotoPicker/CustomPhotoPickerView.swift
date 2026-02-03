import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "CustomPhotoPicker")

/// 커스텀 사진 피커 - DKImagePickerController 대체
/// - Recents 앨범 없음 (날짜 필터링된 사진만 표시)
/// - Swipe drag 선택 지원
/// - 날짜 필터: 오늘, 이번 주, 이번 달, 최근 3개월, 전체
struct CustomPhotoPickerView: View {
    // MARK: - Properties

    /// 선택 완료 콜백
    var onSelect: (([PHAsset]) -> Void)?

    /// 취소 콜백
    var onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var assetManager = PhotoAssetManager()

    // 선택된 사진 (localIdentifier 저장)
    @State private var selectedAssets: Set<String> = []

    // 현재 선택된 날짜 필터
    @State private var selectedDateFilter: DateFilterRange = .thisMonth

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 날짜 필터 칩
                    dateFilterSection

                    // 사진 그리드 또는 상태 뷰
                    contentView
                }

                // 하단 선택 완료 버튼 (사진이 선택된 경우에만 표시)
                if !selectedAssets.isEmpty {
                    bottomSelectionButton
                }
            }
            .background(WanderColors.background)
            .navigationTitle("사진 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 좌측 취소 버튼만
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        logger.info("📷 [CustomPhotoPicker] 취소")
                        onCancel?()
                        dismiss()
                    }
                    .foregroundColor(WanderColors.textSecondary)
                }
            }
            .onAppear {
                logger.info("📷 [CustomPhotoPicker] 나타남")
                Task {
                    await checkAndRequestPermission()
                }
            }
        }
    }

    // MARK: - Bottom Selection Button

    private var bottomSelectionButton: some View {
        VStack(spacing: 0) {
            // 그라데이션 배경
            LinearGradient(
                colors: [WanderColors.background.opacity(0), WanderColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            // 버튼 영역
            Button {
                confirmSelection()
            } label: {
                Text("\(selectedAssets.count)장의 사진 선택")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
            .background(WanderColors.background)
        }
    }

    // MARK: - Date Filter Section

    private var dateFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WanderSpacing.space2) {
                ForEach(DateFilterRange.allCases) { filter in
                    DateFilterChip(
                        title: filter.title,
                        isSelected: selectedDateFilter == filter
                    ) {
                        selectDateFilter(filter)
                    }
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space3)
        }
        .background(WanderColors.background)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch assetManager.authorizationStatus {
        case .notDetermined:
            permissionRequestView

        case .restricted, .denied:
            permissionDeniedView

        case .authorized, .limited:
            if assetManager.isLoading {
                loadingView
            } else if assetManager.assets.isEmpty {
                emptyView
            } else {
                PhotoGridView(
                    assets: assetManager.assets,
                    selectedAssets: $selectedAssets,
                    thumbnailSize: CGSize(width: 200, height: 200)
                )
            }

        @unknown default:
            permissionRequestView
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            ProgressView()
                .scaleEffect(1.5)
            Text("사진을 불러오는 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.textTertiary)

            Text("선택한 기간에 사진이 없습니다")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Text("다른 기간을 선택해 보세요")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionRequestView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.primary)

            Text("사진 접근 권한이 필요합니다")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text("여행 기록을 만들기 위해\n사진 라이브러리에 접근합니다")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await assetManager.requestAuthorization()
                }
            } label: {
                Text("권한 허용")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusMedium)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.top, WanderSpacing.space4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.warning)

            Text("사진 접근이 거부되었습니다")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text("설정에서 사진 접근 권한을\n허용해 주세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                openSettings()
            } label: {
                Text("설정으로 이동")
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusMedium)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.top, WanderSpacing.space4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func checkAndRequestPermission() async {
        assetManager.checkAuthorizationStatus()

        switch assetManager.authorizationStatus {
        case .authorized, .limited:
            await assetManager.fetchAssets(for: selectedDateFilter)
        case .notDetermined:
            // UI에서 버튼으로 요청
            break
        default:
            break
        }
    }

    private func selectDateFilter(_ filter: DateFilterRange) {
        guard filter != selectedDateFilter else { return }

        logger.info("📷 [CustomPhotoPicker] 날짜 필터 변경: \(filter.title)")
        selectedDateFilter = filter
        selectedAssets.removeAll()  // 선택 초기화

        Task {
            await assetManager.fetchAssets(for: filter)
        }
    }

    private func confirmSelection() {
        // localIdentifier로 PHAsset 조회
        let selectedPHAssets = assetManager.assets.filter { asset in
            selectedAssets.contains(asset.localIdentifier)
        }

        logger.info("📷 [CustomPhotoPicker] 선택 완료: \(selectedPHAssets.count)장")
        onSelect?(selectedPHAssets)
        dismiss()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Date Filter Chip

struct DateFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WanderTypography.caption1)
                .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space2)
                .background(
                    Capsule()
                        .fill(isSelected ? WanderColors.primary : WanderColors.surface)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    CustomPhotoPickerView(
        onSelect: { assets in
            print("선택됨: \(assets.count)장")
        },
        onCancel: {
            print("취소됨")
        }
    )
}
