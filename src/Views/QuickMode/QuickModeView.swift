import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "QuickModeView")

/// "지금 뭐해?" 퀵 모드 뷰
struct QuickModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var isLoading = true
    @State private var showAnalyzing = false
    @State private var viewModel = PhotoSelectionViewModel()

    /// 분석 완료 후 저장된 기록 콜백
    var onSaveComplete: ((TravelRecord) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if recentPhotos.isEmpty {
                    emptyStateView
                } else {
                    photoSelectionView
                }

                // Bottom action bar
                if !selectedAssets.isEmpty {
                    actionBar
                }
            }
            .background(WanderColors.background)
            .navigationTitle("지금 뭐해?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                logger.info("💬 [QuickMode] 화면 나타남")
                loadRecentPhotos()
            }
            .fullScreenCover(isPresented: $showAnalyzing, onDismiss: {
                // AnalyzingView/ResultView에서 저장 완료 후 QuickModeView도 닫기
                if viewModel.shouldDismissPhotoSelection {
                    dismiss()
                }
            }) {
                AnalyzingView(viewModel: viewModel, onSaveComplete: onSaveComplete)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("최근 사진을 불러오는 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("최근 24시간 내 촬영한\n사진이 없어요")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("사진을 촬영하고 다시 시도해 보세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Photo Selection View
    private var photoSelectionView: some View {
        VStack(spacing: WanderSpacing.space4) {
            // Header
            HStack {
                Text("최근 24시간 (\(recentPhotos.count)장)")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
                Spacer()

                if selectedAssets.count < recentPhotos.count && selectedAssets.count < 10 {
                    Button("전체 선택") {
                        selectedAssets = Array(recentPhotos.prefix(10))
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.primary)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.top, WanderSpacing.space4)

            // Photo grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: WanderSpacing.space1),
                    GridItem(.flexible(), spacing: WanderSpacing.space1),
                    GridItem(.flexible(), spacing: WanderSpacing.space1),
                    GridItem(.flexible(), spacing: WanderSpacing.space1)
                ], spacing: WanderSpacing.space1) {
                    ForEach(recentPhotos, id: \.localIdentifier) { asset in
                        QuickModePhotoCell(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset),
                            selectionOrder: selectedAssets.firstIndex(of: asset).map { $0 + 1 }
                        ) {
                            toggleSelection(asset)
                        }
                    }
                }
                .padding(.horizontal, WanderSpacing.space2)
            }

            // Info text
            Text("최대 10장까지 선택할 수 있어요")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
                .padding(.bottom, WanderSpacing.space2)
        }
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedAssets.count)장 선택됨")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    let withGPS = selectedAssets.filter { $0.location != nil }.count
                    Text("GPS 정보 있음: \(withGPS)장")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Spacer()

                Button(action: {
                    // NOTE: LookbackView와 동일한 패턴 - ViewModel에 선택된 사진 설정 후 분석 시작
                    viewModel.selectedAssets = selectedAssets
                    viewModel.shouldDismissPhotoSelection = false
                    showAnalyzing = true
                }) {
                    Text("분석하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, WanderSpacing.space6)
                        .padding(.vertical, WanderSpacing.space3)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusFull)
                }
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
        }
    }

    // MARK: - Helper Functions
    private func loadRecentPhotos() {
        logger.info("💬 [QuickMode] 최근 24시간 사진 로드 시작")

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@",
            yesterday as NSDate
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        logger.info("💬 [QuickMode] 최근 24시간 사진: \(assets.count)장")

        DispatchQueue.main.async {
            self.recentPhotos = assets
            self.isLoading = false
        }
    }

    private func toggleSelection(_ asset: PHAsset) {
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        } else if selectedAssets.count < 10 {
            selectedAssets.append(asset)
        }
    }
}

// MARK: - Quick Mode Photo Cell
// NOTE: PHImageManager 요청을 onDisappear에서 취소하여 메모리 누수 방지
struct QuickModePhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let selectionOrder: Int?
    let action: () -> Void

    @State private var thumbnail: UIImage?
    /// PHImageManager 요청 ID (취소용)
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(WanderColors.surface)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                }

                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(WanderColors.primary.opacity(0.3))

                    ZStack {
                        Circle()
                            .fill(WanderColors.primary)
                            .frame(width: 20, height: 20)

                        if let order = selectionOrder {
                            Text("\(order)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(WanderSpacing.space1)
                }

                // GPS indicator
                if asset.location != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .padding(2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(2)
                            Spacer()
                        }
                    }
                    .padding(2)
                }
            }
            .cornerRadius(WanderSpacing.radiusSmall)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // IMPORTANT: 뷰가 사라질 때 PHImageManager 요청 취소
            if let requestID = requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        // IMPORTANT: 요청 ID 저장하여 취소 가능하게 함
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { [self] image, _ in
            self.thumbnail = image
        }
    }
}

#Preview {
    QuickModeView()
}
