import SwiftUI
import SwiftData
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "HomeView")

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelRecord.createdAt, order: .reverse) private var records: [TravelRecord]
    @State private var showPhotoSelection = false
    @State private var showQuickMode = false
    @State private var showLookback = false
    @State private var navigationPath = NavigationPath()
    @State private var savedRecordId: UUID?

    /// 상세 페이지 진입 시 탭바 스와이프 비활성화용 (부모에서 바인딩)
    @Binding var isNavigationActive: Bool

    init(isNavigationActive: Binding<Bool> = .constant(false)) {
        _isNavigationActive = isNavigationActive
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // 커스텀 헤더
                customHeader

                ZStack {
                    ScrollView {
                        VStack(spacing: WanderSpacing.space6) {
                            // Greeting
                            greetingSection

                            // Quick Action Cards (2 columns)
                            quickActionSection

                            // Recent Records Section
                            recentRecordsSection
                        }
                        .padding(.horizontal, WanderSpacing.screenMargin)
                        .padding(.top, WanderSpacing.space4)
                        // ⚠️ 하단 패딩: 탭바(49pt) + FAB(56pt) + 여백(20pt) = 125pt
                        // 탭바에 가려지지 않도록 충분한 공간 확보 필수
                        .padding(.bottom, records.isEmpty ? WanderSpacing.space4 : 125)
                    }
                    .background(WanderColors.background)

                    // FAB (Floating Action Button) - 기록이 있을 때만 표시
                    if !records.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                fabButton
                                    .padding(.trailing, WanderSpacing.screenMargin)
                                    // ⚠️ FAB 하단 패딩: 탭바 높이(49pt) + 여백(16pt) = 65pt
                                    // 탭바에 가려지지 않도록 반드시 49pt 이상 유지 필요
                                    .padding(.bottom, 65)
                            }
                        }
                    }
                }
            }
            .background(WanderColors.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { recordId in
                if let record = records.first(where: { $0.id == recordId }) {
                    RecordDetailFullView(record: record)
                }
            }
            .sheet(isPresented: $showPhotoSelection) {
                PhotoPickerWithAnalysis(onSaveComplete: { savedRecord in
                    logger.info("🏠 [HomeView] 저장 완료 콜백 받음: \(savedRecord.title)")
                    savedRecordId = savedRecord.id
                })
            }
            .sheet(isPresented: $showQuickMode) {
                QuickModeView()
            }
            .sheet(isPresented: $showLookback) {
                LookbackView()
            }
            .onAppear {
                logger.info("🏠 [HomeView] 나타남 - 저장된 기록: \(records.count)개")
                for (index, record) in records.prefix(5).enumerated() {
                    logger.info("🏠 [HomeView] 기록[\(index)]: \(record.title), days: \(record.days.count), places: \(record.placeCount)")
                }
            }
            .onChange(of: savedRecordId) { _, newRecordId in
                if let recordId = newRecordId {
                    logger.info("🏠 [HomeView] 저장된 기록으로 이동: \(recordId)")
                    // 약간의 딜레이 후 이동 (sheet 닫힘 애니메이션 완료 대기)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigationPath.append(recordId)
                        savedRecordId = nil
                    }
                }
            }
            .onChange(of: navigationPath) { _, newPath in
                // 네비게이션 경로가 비어있지 않으면 상세 페이지에 있음 -> 탭바 스와이프 비활성화
                isNavigationActive = !newPath.isEmpty
            }
        }
    }

    // MARK: - Custom Header
    private var customHeader: some View {
        HStack {
            Spacer()
            Text("Wander")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(WanderColors.primary)
            Spacer()
        }
        .frame(height: 44)
        .background(WanderColors.background)
    }

    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space1) {
            Text("home.greeting.line1".localized)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)
            Text("home.greeting.line2".localized)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - FAB Button
    private var fabButton: some View {
        Button(action: {
            showPhotoSelection = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(WanderColors.primary)
                .clipShape(Circle())
                .shadow(color: WanderColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Quick Action Section
    private var quickActionSection: some View {
        HStack(spacing: WanderSpacing.space3) {
            // 지금 뭐해?
            QuickActionCard(
                icon: "bubble.left.fill",
                title: "home.quickMode".localized,
                subtitle: "home.quickMode.subtitle".localized,
                backgroundColor: WanderColors.primaryPale
            ) {
                showQuickMode = true
            }

            // 돌아보기
            QuickActionCard(
                icon: "arrow.counterclockwise",
                title: "home.lookback".localized,
                subtitle: "home.lookback.subtitle".localized,
                backgroundColor: WanderColors.primaryPale,
                showPeriodBadge: true
            ) {
                showLookback = true
            }
        }
    }

    // MARK: - Recent Records Section
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("home.recentRecords".localized)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            if records.isEmpty {
                emptyStateView
            } else {
                recentRecordsList
            }
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()
                .frame(height: WanderSpacing.space8)

            // Route Illustration
            RouteIllustration()
                .frame(height: 150)

            VStack(spacing: WanderSpacing.space2) {
                Text("home.empty.title".localized)
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text("home.empty.subtitle".localized)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Button(action: {
                showPhotoSelection = true
            }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "plus")
                    Text("home.createRecord".localized)
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .padding(.top, WanderSpacing.space4)

            Spacer()
                .frame(height: WanderSpacing.space8)
        }
    }

    // MARK: - Recent Records List
    private var recentRecordsList: some View {
        LazyVStack(spacing: WanderSpacing.space4) {
            ForEach(records.prefix(5)) { record in
                Button {
                    navigationPath.append(record.id)
                } label: {
                    RecordCard(record: record)
                }
                .buttonStyle(.plain)
                .onAppear {
                    logger.info("🏠 [HomeView] RecordCard 표시: \(record.title)")
                }
            }
        }
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    var showPeriodBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(WanderColors.primary)

                Spacer()

                // Title
                Text(title)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                // Period Badge (돌아보기 전용)
                if showPeriodBadge {
                    HStack(spacing: 4) {
                        Text("이번 주")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(WanderColors.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WanderColors.primary.opacity(0.15))
                    .cornerRadius(WanderSpacing.radiusSmall)
                }

                // Subtitle
                Text(subtitle)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .padding(WanderSpacing.space4)
            .background(backgroundColor)
            .cornerRadius(WanderSpacing.radiusLarge)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Card
struct RecordCard: View {
    let record: TravelRecord

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // 멀티 포토 썸네일 (폴라로이드 스타일)
            MultiPhotoThumbnail(record: record)
                .frame(height: 120)

            VStack(alignment: .leading, spacing: WanderSpacing.space1) {
                Text(record.title)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Text(formatDateRange(start: record.startDate, end: record.endDate))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)

                HStack(spacing: WanderSpacing.space4) {
                    Label("\(record.placeCount)곳", systemImage: "mappin")
                    Label("\(Int(record.totalDistance))km", systemImage: "car.fill")
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusXXL)
        .elevation1()
        .contentShape(Rectangle())  // 전체 영역 터치 가능
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

// MARK: - Multi Photo Thumbnail (폴라로이드 스타일 콜라주)
struct MultiPhotoThumbnail: View {
    let record: TravelRecord
    @State private var thumbnails: [UIImage] = []
    @State private var isLoading = true

    /// 썸네일에 표시할 최대 사진 수
    private let maxPhotos = 4

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                if thumbnails.isEmpty && !isLoading {
                    // 사진 없음
                    placeholderView
                } else if thumbnails.isEmpty && isLoading {
                    // 로딩 중
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                        .fill(WanderColors.primaryPale)
                        .overlay(
                            ProgressView()
                                .tint(WanderColors.primary)
                        )
                } else {
                    // 사진 개수에 따른 레이아웃
                    thumbnailLayout(size: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium))
        }
        .onAppear {
            loadThumbnails()
        }
    }

    // MARK: - Layouts

    @ViewBuilder
    private func thumbnailLayout(size: CGSize) -> some View {
        let spacing: CGFloat = 2

        switch thumbnails.count {
        case 1:
            // 1장: 전체 커버
            thumbnailImage(thumbnails[0], width: size.width, height: size.height)

        case 2:
            // 2장: 좌우 배치
            HStack(spacing: spacing) {
                let cellWidth = (size.width - spacing) / 2
                thumbnailImage(thumbnails[0], width: cellWidth, height: size.height)
                thumbnailImage(thumbnails[1], width: cellWidth, height: size.height)
            }

        case 3:
            // 3장: 좌측 큰 1장 + 우측 2장
            HStack(spacing: spacing) {
                let leftWidth = size.width * 0.55
                let rightWidth = size.width - leftWidth - spacing
                let rightCellHeight = (size.height - spacing) / 2

                thumbnailImage(thumbnails[0], width: leftWidth, height: size.height)

                VStack(spacing: spacing) {
                    thumbnailImage(thumbnails[1], width: rightWidth, height: rightCellHeight)
                    thumbnailImage(thumbnails[2], width: rightWidth, height: rightCellHeight)
                }
            }

        default:
            // 4장+: 2x2 그리드
            VStack(spacing: spacing) {
                let cellWidth = (size.width - spacing) / 2
                let cellHeight = (size.height - spacing) / 2

                HStack(spacing: spacing) {
                    thumbnailImage(thumbnails[0], width: cellWidth, height: cellHeight)
                    thumbnailImage(thumbnails[1], width: cellWidth, height: cellHeight)
                }
                HStack(spacing: spacing) {
                    thumbnailImage(thumbnails[2], width: cellWidth, height: cellHeight)
                    if thumbnails.count > 3 {
                        thumbnailImage(thumbnails[3], width: cellWidth, height: cellHeight)
                    }
                }
            }
        }
    }

    private func thumbnailImage(_ image: UIImage, width: CGFloat, height: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
            .fill(WanderColors.primaryPale)
            .overlay(
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 32))
                    .foregroundColor(WanderColors.primary)
            )
    }

    // MARK: - Load Thumbnails

    private func loadThumbnails() {
        let assetIds = Array(record.allPhotoAssetIdentifiers.prefix(maxPhotos))

        guard !assetIds.isEmpty else {
            isLoading = false
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)

        guard fetchResult.count > 0 else {
            logger.warning("🏠 [MultiPhotoThumbnail] PHAsset 찾을 수 없음")
            isLoading = false
            return
        }

        // 순서 유지를 위해 딕셔너리로 로드
        var loadedImages: [String: UIImage] = [:]
        let group = DispatchGroup()

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        fetchResult.enumerateObjects { asset, _, _ in
            group.enter()

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // 썸네일 이미지만 처리 (고해상도 이미지 무시)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let image = image {
                    DispatchQueue.main.async {
                        loadedImages[asset.localIdentifier] = image

                        // 저해상도 이미지라도 일단 표시
                        if isDegraded || loadedImages.count == fetchResult.count {
                            // 원래 순서대로 정렬
                            let orderedImages = assetIds.compactMap { loadedImages[$0] }
                            if !orderedImages.isEmpty {
                                self.thumbnails = orderedImages
                                self.isLoading = false
                            }
                        }
                    }
                }

                if !isDegraded {
                    group.leave()
                }
            }
        }

        // 타임아웃 처리
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.isLoading && !loadedImages.isEmpty {
                let orderedImages = assetIds.compactMap { loadedImages[$0] }
                self.thumbnails = orderedImages
                self.isLoading = false
            }
        }
    }
}

// MARK: - Route Illustration
struct RouteIllustration: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Dashed path
                Path { path in
                    path.move(to: CGPoint(x: width * 0.2, y: height * 0.8))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.5, y: height * 0.3),
                        control: CGPoint(x: width * 0.3, y: height * 0.5)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.8, y: height * 0.7),
                        control: CGPoint(x: width * 0.7, y: height * 0.2)
                    )
                }
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(WanderColors.border)

                // Pin marker
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(WanderColors.primary)
                    .position(x: width * 0.5, y: height * 0.25)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
