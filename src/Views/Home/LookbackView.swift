import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "LookbackView")

/// 돌아보기 - 기간별 사진 자동 수집 화면
struct LookbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: LookbackPeriod = .thisWeek
    @State private var photos: [PHAsset] = []
    @State private var selectedPhotos: Set<String> = []
    @State private var isLoading = true
    @State private var showAnalyzing = false
    @State private var viewModel = PhotoSelectionViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period Selection
                periodSelector
                    .padding(.horizontal, WanderSpacing.screenMargin)
                    .padding(.vertical, WanderSpacing.space4)

                // Date Range Info
                dateRangeInfo
                    .padding(.horizontal, WanderSpacing.screenMargin)
                    .padding(.bottom, WanderSpacing.space4)

                if isLoading {
                    loadingView
                } else if photos.isEmpty {
                    emptyStateView
                } else {
                    // Photo Grid
                    photoGrid

                    // Selection Counter
                    selectionCounter
                }

                // Bottom Action
                if !photos.isEmpty && !selectedPhotos.isEmpty {
                    actionButton
                        .padding(.horizontal, WanderSpacing.screenMargin)
                        .padding(.vertical, WanderSpacing.space4)
                }
            }
            .background(WanderColors.background)
            .navigationTitle("돌아보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                loadPhotos()
            }
            .onChange(of: selectedPeriod) { _, _ in
                loadPhotos()
            }
            .fullScreenCover(isPresented: $showAnalyzing, onDismiss: {
                // AnalyzingView/ResultView가 닫히면 LookbackView도 닫기
                if viewModel.shouldDismissPhotoSelection {
                    dismiss()
                }
            }) {
                AnalyzingView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(LookbackPeriod.allCases) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.title)
                        .font(WanderTypography.caption1)
                        .foregroundColor(selectedPeriod == period ? .white : WanderColors.textSecondary)
                        .padding(.horizontal, WanderSpacing.space3)
                        .padding(.vertical, WanderSpacing.space2)
                        .background(selectedPeriod == period ? WanderColors.primary : WanderColors.surface)
                        .cornerRadius(WanderSpacing.radiusMedium)
                }
            }
        }
        .padding(WanderSpacing.space1)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusMedium)
    }

    // MARK: - Date Range Info
    private var dateRangeInfo: some View {
        let (startDate, endDate) = selectedPeriod.dateRange

        return VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(WanderColors.primary)
                Text(formatDateRange(start: startDate, end: endDate))
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.primary)
            }

            Text("GPS가 있는 사진 \(photos.count)장")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WanderSpacing.space4)
        .background(WanderColors.primaryPale)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("사진을 찾고 있어요...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(WanderColors.textTertiary)

            VStack(spacing: WanderSpacing.space2) {
                Text("선택한 기간에 위치 정보가")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
                Text("있는 사진이 없어요")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Text("다른 기간을 선택해 보세요")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)

            Spacer()
        }
    }

    // MARK: - Photo Grid
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: WanderSpacing.space1), count: 4), spacing: WanderSpacing.space1) {
                ForEach(photos, id: \.localIdentifier) { asset in
                    PhotoThumbnail(
                        asset: asset,
                        isSelected: selectedPhotos.contains(asset.localIdentifier),
                        onToggle: {
                            toggleSelection(asset)
                        }
                    )
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
        }
    }

    // MARK: - Selection Counter
    private var selectionCounter: some View {
        HStack {
            Spacer()
            Text("\(photos.count)장 중 \(selectedPhotos.count)장 선택됨")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
            Spacer()
        }
        .padding(.vertical, WanderSpacing.space3)
        .background(WanderColors.surface)
        .overlay(
            Rectangle()
                .fill(WanderColors.border)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            startAnalysis()
        }) {
            Text("하이라이트 만들기")
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
        }
    }

    // MARK: - Helper Functions
    private func loadPhotos() {
        isLoading = true
        selectedPhotos.removeAll()

        let (startDate, endDate) = selectedPeriod.dateRange

        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            // Note: PhotoKit doesn't support "location != nil" predicate
            // Filter by date range only, then filter by location in memory
            fetchOptions.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", startDate as NSDate, endDate as NSDate)
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                // Filter: only photos with GPS location
                if asset.location != nil {
                    assets.append(asset)
                }
            }

            DispatchQueue.main.async {
                self.photos = assets
                self.selectedPhotos = Set(assets.map { $0.localIdentifier })
                self.isLoading = false
                logger.info("🔄 [LookbackView] 사진 로드 완료: \(assets.count)장 (GPS 있는 사진만)")
            }
        }
    }

    private func toggleSelection(_ asset: PHAsset) {
        if selectedPhotos.contains(asset.localIdentifier) {
            selectedPhotos.remove(asset.localIdentifier)
        } else {
            selectedPhotos.insert(asset.localIdentifier)
        }
    }

    private func startAnalysis() {
        logger.info("🔄 [LookbackView] 분석 시작 - \(selectedPhotos.count)장")
        // ViewModel에 선택된 사진 설정
        viewModel.selectedAssets = photos.filter { selectedPhotos.contains($0.localIdentifier) }
        viewModel.shouldDismissPhotoSelection = false
        showAnalyzing = true
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        // 같은 날이면 하나만 표시
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatDate(start)
        }
        return "\(formatDate(start)) ~ \(formatDate(end))"
    }
}

// MARK: - Lookback Period Enum
enum LookbackPeriod: String, CaseIterable, Identifiable {
    case thisWeek = "thisWeek"
    case lastWeek = "lastWeek"
    case thisMonth = "thisMonth"
    case last30Days = "last30Days"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisWeek: return "이번 주"
        case .lastWeek: return "지난 주"
        case .thisMonth: return "이번 달"
        case .last30Days: return "최근 30일"
        }
    }

    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .thisWeek:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (startOfWeek, now)

        case .lastWeek:
            let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let startOfLastWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek)!
            let endOfLastWeek = calendar.date(byAdding: .second, value: -1, to: startOfThisWeek)!
            return (startOfLastWeek, endOfLastWeek)

        case .thisMonth:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (startOfMonth, now)

        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
            return (thirtyDaysAgo, now)
        }
    }
}

// MARK: - Photo Thumbnail
// NOTE: PHImageManager 요청을 onDisappear에서 취소하여 메모리 누수 방지
struct PhotoThumbnail: View {
    let asset: PHAsset
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var image: UIImage?
    /// PHImageManager 요청 ID (취소용)
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(WanderColors.surface)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                }

                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(WanderColors.primary)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .padding(WanderSpacing.space1)
                }
            }
            .cornerRadius(WanderSpacing.radiusMedium)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // IMPORTANT: 뷰가 사라질 때 PHImageManager 요청 취소
            if let requestID = requestID {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
    }

    private var thumbnailSize: CGFloat {
        (UIScreen.main.bounds.width - 40 - 12) / 4 // 4 columns with gaps
    }

    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        // IMPORTANT: 요청 ID 저장하여 취소 가능하게 함
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { [self] image, _ in
            if let image = image {
                self.image = image
            }
        }
    }
}

#Preview {
    LookbackView()
}
