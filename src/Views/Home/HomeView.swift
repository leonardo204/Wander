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

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                    .padding(.bottom, records.isEmpty ? WanderSpacing.space4 : 80) // FAB 공간 확보
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
                                .padding(.bottom, WanderSpacing.space4)
                        }
                    }
                }
            }
            .navigationTitle("Wander")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { recordId in
                if let record = records.first(where: { $0.id == recordId }) {
                    RecordDetailFullView(record: record)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Wander")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(WanderColors.primary)
                }
            }
            .sheet(isPresented: $showPhotoSelection) {
                PhotoSelectionView(onSaveComplete: { savedRecord in
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
        }
    }

    // MARK: - Greeting Section
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space1) {
            Text("오늘 어떤 이야기를")
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)
            Text("만들어 볼까요?")
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
                title: "지금 뭐해?",
                subtitle: "사진 몇 장으로\n바로 공유",
                backgroundColor: WanderColors.primaryPale
            ) {
                showQuickMode = true
            }

            // 돌아보기
            QuickActionCard(
                icon: "arrow.counterclockwise",
                title: "돌아보기",
                subtitle: "자동 하이라이트\n생성",
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
            Text("최근 기록")
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
                Text("아직 기록이 없어요")
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text("첫 번째 여행을 기록해 보세요")
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Button(action: {
                showPhotoSelection = true
            }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "plus")
                    Text("여행 기록 만들기")
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
                NavigationLink(value: record.id) {
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
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Thumbnail from actual photo
            ZStack {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(WanderSpacing.radiusMedium)
                } else {
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                        .fill(WanderColors.primaryPale)
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 32))
                                .foregroundColor(WanderColors.primary)
                        )
                }
            }
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
        .onAppear {
            loadThumbnail()
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    private func loadThumbnail() {
        guard let assetId = record.firstPhotoAssetIdentifier else {
            logger.info("🏠 [RecordCard] 썸네일 없음 - \(record.title)")
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            logger.warning("🏠 [RecordCard] PHAsset 찾을 수 없음 - \(assetId)")
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 400, height: 240),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
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
