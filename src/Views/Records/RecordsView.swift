import SwiftUI
import SwiftData
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "RecordsView")

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TravelRecord.createdAt, order: .reverse) private var records: [TravelRecord]
    @State private var searchText = ""
    @State private var selectedFilter: RecordFilter = .all
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: TravelRecord?

    var filteredRecords: [TravelRecord] {
        var result = records

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .travel:
            result = result.filter { $0.recordType == "travel" }
        case .daily:
            result = result.filter { $0.recordType == "daily" }
        case .weekly:
            result = result.filter { $0.recordType == "weekly" }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                filterSection

                if records.isEmpty {
                    emptyStateView
                } else if filteredRecords.isEmpty {
                    noResultsView
                } else {
                    recordsList
                }
            }
            .background(WanderColors.background)
            .navigationTitle("기록")
            .searchable(text: $searchText, prompt: "기록 검색")
            .onAppear {
                logger.info("📚 [RecordsView] 나타남 - 전체 기록: \(records.count)개")
            }
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
    }

    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WanderSpacing.space2) {
                ForEach(RecordFilter.allCases) { filter in
                    FilterChip(
                        title: filter.title,
                        count: countForFilter(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space3)
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("아직 기록이 없어요")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            Text("여행을 기록하고 추억을 저장해 보세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(WanderColors.textTertiary)

            Text("검색 결과가 없습니다")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Records List
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: WanderSpacing.space4) {
                ForEach(filteredRecords) { record in
                    NavigationLink(destination: RecordDetailFullView(record: record)) {
                        RecordListCard(record: record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
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

    // MARK: - Helper Functions
    private func countForFilter(_ filter: RecordFilter) -> Int {
        switch filter {
        case .all:
            return records.count
        case .travel:
            return records.filter { $0.recordType == "travel" }.count
        case .daily:
            return records.filter { $0.recordType == "daily" }.count
        case .weekly:
            return records.filter { $0.recordType == "weekly" }.count
        }
    }

    private func deleteRecord(_ record: TravelRecord) {
        modelContext.delete(record)
        recordToDelete = nil
    }
}

// MARK: - Record Filter
enum RecordFilter: String, CaseIterable, Identifiable {
    case all
    case travel
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "전체"
        case .travel: return "여행"
        case .daily: return "일상"
        case .weekly: return "주간"
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WanderSpacing.space1) {
                Text(title)
                Text("(\(count))")
                    .opacity(0.7)
            }
            .font(WanderTypography.caption1)
            .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
            .padding(.horizontal, WanderSpacing.space4)
            .padding(.vertical, WanderSpacing.space2)
            .background(isSelected ? WanderColors.primary : WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusFull)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusFull)
                    .stroke(isSelected ? Color.clear : WanderColors.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Record List Card
struct RecordListCard: View {
    let record: TravelRecord
    @State private var thumbnails: [UIImage] = []

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Header with date badge
            HStack {
                DateBadge(date: record.startDate)
                Spacer()
                RecordTypeBadge(type: record.recordType)
            }

            // Title
            Text(record.title)
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            // Date range
            Text(formatDateRange(start: record.startDate, end: record.endDate))
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)

            // Photo thumbnails strip (최대 4장)
            if !thumbnails.isEmpty {
                HStack(spacing: 4) {
                    ForEach(0..<min(thumbnails.count, 4), id: \.self) { index in
                        Image(uiImage: thumbnails[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipped()
                            .cornerRadius(WanderSpacing.radiusSmall)
                    }
                    if record.photoCount > 4 {
                        ZStack {
                            RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                                .fill(WanderColors.primaryPale)
                                .frame(width: 50, height: 50)
                            Text("+\(record.photoCount - 4)")
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.primary)
                        }
                    }
                    Spacer()
                }
            }

            // Stats
            HStack(spacing: WanderSpacing.space5) {
                StatBadge(icon: "mappin", value: "\(record.placeCount)곳")
                StatBadge(icon: "car.fill", value: "\(Int(record.totalDistance))km")
                StatBadge(icon: "photo", value: "\(record.photoCount)장")
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusXL)
        .elevation1()
        .onAppear {
            loadThumbnails()
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
    }

    private func loadThumbnails() {
        let assetIds = Array(record.allPhotoAssetIdentifiers.prefix(4))
        guard !assetIds.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)

        let options = PHImageRequestOptions()
        // Use .fastFormat to ensure single callback (not .opportunistic which calls multiple times)
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        var loadedImages: [UIImage] = []
        var pendingCount = fetchResult.count

        fetchResult.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 100, height: 100),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        loadedImages.append(image)
                    }
                    pendingCount -= 1
                    if pendingCount == 0 {
                        self.thumbnails = loadedImages
                    }
                }
            }
        }
    }
}

// MARK: - Date Badge
struct DateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(monthString)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WanderColors.primary)

            Text(dayString)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(WanderColors.textPrimary)
        }
        .frame(width: 44, height: 44)
        .background(WanderColors.primaryPale)
        .cornerRadius(WanderSpacing.radiusMedium)
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: - Record Type Badge
struct RecordTypeBadge: View {
    let type: String

    var body: some View {
        Text(typeTitle)
            .font(WanderTypography.caption2)
            .foregroundColor(WanderColors.textSecondary)
            .padding(.horizontal, WanderSpacing.space2)
            .padding(.vertical, WanderSpacing.space1)
            .background(WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                    .stroke(WanderColors.border, lineWidth: 1)
            )
    }

    private var typeTitle: String {
        switch type {
        case "travel": return "여행"
        case "daily": return "일상"
        case "weekly": return "주간"
        default: return "기록"
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: WanderSpacing.space1) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
        }
        .font(WanderTypography.caption1)
        .foregroundColor(WanderColors.textTertiary)
    }
}

// MARK: - Record Detail Full View
struct RecordDetailFullView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var showAIStorySheet = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showMapDetail = false
    @State private var showAllPhotos = false

    var body: some View {
        ScrollView {
            VStack(spacing: WanderSpacing.space6) {
                // Header
                headerSection

                // Stats
                statsSection

                // Timeline
                if !record.days.isEmpty {
                    timelineSection
                } else {
                    Text("타임라인 데이터 없음")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textTertiary)
                        .padding()
                }

                // AI Story Section
                aiStoryOrButtonSection
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space4)
        }
        .background(WanderColors.background)
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger.info("📖 [RecordDetailFullView] 나타남")
            logger.info("📖 [RecordDetailFullView] record.title: \(record.title)")
            logger.info("📖 [RecordDetailFullView] record.days.count: \(record.days.count)")
            logger.info("📖 [RecordDetailFullView] record.placeCount: \(record.placeCount)")
            logger.info("📖 [RecordDetailFullView] record.photoCount: \(record.photoCount)")
            logger.info("📖 [RecordDetailFullView] record.totalDistance: \(record.totalDistance)")
            logger.info("📖 [RecordDetailFullView] record.aiStory: \(record.aiStory ?? "nil")")
            for (dayIndex, day) in record.days.enumerated() {
                logger.info("📖 [RecordDetailFullView] Day \(dayIndex): \(day.places.count) places")
                for (placeIndex, place) in day.places.enumerated() {
                    logger.info("📖 [RecordDetailFullView]   Place \(placeIndex): \(place.name)")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showShareSheet = true }) {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { showAIStorySheet = true }) {
                        Label("AI 스토리 생성", systemImage: "sparkles")
                    }
                    Button(action: { showEditSheet = true }) {
                        Label("편집", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "이 기록을 삭제하시겠습니까?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deleteRecord()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제된 기록은 복구할 수 없습니다.")
        }
        .sheet(isPresented: $showShareSheet) {
            ExportOptionsView(record: record)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAIStorySheet) {
            AIStoryView(record: record)
        }
        .sheet(isPresented: $showEditSheet) {
            RecordEditView(record: record)
        }
        .sheet(isPresented: $showMapDetail) {
            RecordMapSheet(record: record)
        }
        .sheet(isPresented: $showAllPhotos) {
            RecordPhotosSheet(record: record)
        }
    }

    @ViewBuilder
    private var aiStoryOrButtonSection: some View {
        if let story = record.aiStory {
            aiStorySection(story: story)
        } else {
            // AI Story Generation Button
            Button(action: { showAIStorySheet = true }) {
                HStack(spacing: WanderSpacing.space3) {
                    ZStack {
                        Circle()
                            .fill(WanderColors.primaryPale)
                            .frame(width: 44, height: 44)

                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(WanderColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 스토리 생성하기")
                            .font(WanderTypography.headline)
                            .foregroundColor(WanderColors.textPrimary)

                        Text("여행 데이터로 감성적인 스토리를 만들어 보세요")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(WanderColors.textTertiary)
                }
                .padding(WanderSpacing.space4)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space2) {
            Text(record.title)
                .font(WanderTypography.title1)
                .foregroundColor(WanderColors.textPrimary)

            Text(formatDateRange())
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            // 장소 카드 - 클릭하면 지도 표시
            Button(action: { showMapDetail = true }) {
                StatCard(icon: "mappin.circle.fill", value: "\(record.placeCount)", label: "장소")
            }
            .buttonStyle(.plain)

            StatCard(icon: "car.fill", value: String(format: "%.1f", record.totalDistance), label: "km")

            // 사진 카드 - 클릭하면 전체 사진 표시
            Button(action: { showAllPhotos = true }) {
                StatCard(icon: "photo.fill", value: "\(record.photoCount)", label: "사진")
            }
            .buttonStyle(.plain)
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("타임라인")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ForEach(record.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                DaySection(day: day)
            }
        }
    }

    private func aiStorySection(story: String) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(WanderColors.primary)
                Text("AI 스토리")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
            }

            Text(story)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .padding(WanderSpacing.space4)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusLarge)
        }
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        return "\(formatter.string(from: record.startDate)) ~ \(formatter.string(from: record.endDate))"
    }

    private func deleteRecord() {
        logger.info("🗑️ [RecordDetailFullView] 기록 삭제: \(record.title)")
        modelContext.delete(record)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Day Section
struct DaySection: View {
    let day: TravelDay

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Day header
            Text("Day \(day.dayNumber)")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space1)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)

            // Places
            ForEach(day.places.sorted { $0.order < $1.order }) { place in
                PlaceRow(place: place)
            }
        }
    }
}

// MARK: - Place Row
struct PlaceRow: View {
    let place: Place
    @State private var showDetail = false
    @State private var thumbnails: [UIImage] = []

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                HStack(spacing: WanderSpacing.space3) {
                    // Time
                    Text(formatTime(place.startTime))
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                        .frame(width: 50, alignment: .leading)

                    // Dot
                    Circle()
                        .fill(WanderColors.primary)
                        .frame(width: 8, height: 8)

                    // Place info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textPrimary)

                        HStack(spacing: WanderSpacing.space2) {
                            Text(place.activityLabel)
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.textSecondary)

                            if !place.photos.isEmpty {
                                Text("· \(place.photos.count)장")
                                    .font(WanderTypography.caption1)
                                    .foregroundColor(WanderColors.textTertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(WanderColors.textTertiary)
                }

                // Photo thumbnails (최대 4장)
                if !thumbnails.isEmpty {
                    HStack(spacing: 4) {
                        Spacer().frame(width: 50 + WanderSpacing.space3 + 8 + WanderSpacing.space3) // 시간 + gap + dot + gap
                        ForEach(0..<min(thumbnails.count, 4), id: \.self) { index in
                            Image(uiImage: thumbnails[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipped()
                                .cornerRadius(WanderSpacing.radiusSmall)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, WanderSpacing.space2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnails()
        }
        .sheet(isPresented: $showDetail) {
            PlaceDetailSheet(place: place)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func loadThumbnails() {
        let assetIds = place.photos.prefix(4).map { $0.assetIdentifier }
        guard !assetIds.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(assetIds), options: nil)

        let options = PHImageRequestOptions()
        // Use .fastFormat to ensure single callback
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        var loadedImages: [UIImage] = []
        var pendingCount = fetchResult.count

        fetchResult.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 88, height: 88),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        loadedImages.append(image)
                    }
                    pendingCount -= 1
                    if pendingCount == 0 {
                        self.thumbnails = loadedImages
                    }
                }
            }
        }
    }
}

// MARK: - Place Detail Sheet
struct PlaceDetailSheet: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [UIImage] = []
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space5) {
                    // Map Section
                    mapSection

                    // Place Info Section
                    placeInfoSection

                    // Photos Section
                    if !place.photos.isEmpty {
                        photosSection
                    }
                }
                .padding(WanderSpacing.screenMargin)
            }
            .background(WanderColors.background)
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                loadPhotos()
            }
            .fullScreenCover(item: Binding(
                get: { selectedPhotoIndex.map { PhotoViewerItem(index: $0) } },
                set: { selectedPhotoIndex = $0?.index }
            )) { item in
                PhotoViewer(photos: photos, initialIndex: item.index)
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("위치")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            PlaceMapView(coordinate: place.coordinate, placeName: place.name)
                .frame(height: 200)
                .cornerRadius(WanderSpacing.radiusLarge)
        }
    }

    private var placeInfoSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack(spacing: WanderSpacing.space3) {
                // Activity Icon
                ZStack {
                    Circle()
                        .fill(WanderColors.primaryPale)
                        .frame(width: 44, height: 44)

                    Text(activityEmoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(WanderTypography.title3)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }

            Divider()

            // Details
            HStack(spacing: WanderSpacing.space6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("방문 시간")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                    Text(formatTime(place.startTime))
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("활동")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                    Text(place.activityLabel)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("사진")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                    Text("\(place.photos.count)장")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textPrimary)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text("사진")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(0..<photos.count, id: \.self) { index in
                    Button(action: { selectedPhotoIndex = index }) {
                        Image(uiImage: photos[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                            .clipped()
                            .cornerRadius(WanderSpacing.radiusSmall)
                    }
                }
            }
        }
    }

    private var activityEmoji: String {
        switch place.placeType {
        case "cafe": return "☕"
        case "restaurant": return "🍽️"
        case "beach": return "🏖️"
        case "mountain": return "⛰️"
        case "tourist": return "🏛️"
        case "shopping": return "🛍️"
        case "culture": return "🎭"
        case "airport": return "✈️"
        default: return "📍"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func loadPhotos() {
        let assetIds = place.photos.map { $0.assetIdentifier }
        guard !assetIds.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        var loadedImages: [UIImage] = []
        var pendingCount = fetchResult.count

        fetchResult.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        loadedImages.append(image)
                    }
                    pendingCount -= 1
                    if pendingCount == 0 {
                        self.photos = loadedImages
                    }
                }
            }
        }
    }
}

// MARK: - Place Map View
import MapKit
import CoreLocation

struct PlaceMapView: View {
    let coordinate: CLLocationCoordinate2D
    let placeName: String

    @State private var camera: MapCameraPosition

    init(coordinate: CLLocationCoordinate2D, placeName: String) {
        self.coordinate = coordinate
        self.placeName = placeName
        self._camera = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        Map(position: $camera) {
            Annotation(placeName, coordinate: coordinate) {
                ZStack {
                    Circle()
                        .fill(WanderColors.primary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "mappin")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .mapStyle(.standard)
    }
}

// MARK: - Photo Viewer Item
struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Photo Viewer
struct PhotoViewer: View {
    let photos: [UIImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    init(photos: [UIImage], initialIndex: Int) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(0..<photos.count, id: \.self) { index in
                    ZoomableImageView(image: photos[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Top bar
            VStack {
                HStack {
                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                // Bottom counter
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(WanderTypography.caption1)
                    .foregroundColor(.white)
                    .padding(.horizontal, WanderSpacing.space4)
                    .padding(.vertical, WanderSpacing.space2)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(WanderSpacing.radiusFull)
                    .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale < 1.0 {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }
}

// MARK: - Export Options View
struct ExportOptionsView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var exportedText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("공유 형식") {
                    Button(action: { shareAsText() }) {
                        Label("텍스트로 공유", systemImage: "doc.text")
                    }
                    Button(action: { shareAsImage() }) {
                        Label("이미지로 공유", systemImage: "photo")
                    }
                }

                Section("내보내기") {
                    Button(action: { exportAsMarkdown() }) {
                        Label("Markdown으로 내보내기", systemImage: "doc.richtext")
                    }
                    Button(action: { exportAsHTML() }) {
                        Label("HTML로 내보내기", systemImage: "globe")
                    }
                }
            }
            .navigationTitle("공유 및 내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [exportedText])
            }
        }
    }

    private func shareAsText() {
        exportedText = generateTextExport()
        showShareSheet = true
    }

    private func shareAsImage() {
        // TODO: Generate share card image
        exportedText = "이미지 공유 기능은 준비 중입니다."
        showShareSheet = true
    }

    private func exportAsMarkdown() {
        exportedText = generateMarkdownExport()
        showShareSheet = true
    }

    private func exportAsHTML() {
        exportedText = generateHTMLExport()
        showShareSheet = true
    }

    private func generateTextExport() -> String {
        var text = "📍 \(record.title)\n"
        text += "📅 \(formatDate(record.startDate)) ~ \(formatDate(record.endDate))\n\n"

        for day in record.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            text += "Day \(day.dayNumber)\n"
            for place in day.places.sorted(by: { $0.order < $1.order }) {
                let time = formatTime(place.startTime)
                text += "  \(time) - \(place.name) (\(place.activityLabel))\n"
            }
            text += "\n"
        }

        text += "🚗 총 이동거리: \(Int(record.totalDistance))km\n"
        text += "📸 사진: \(record.photoCount)장\n"

        return text
    }

    private func generateMarkdownExport() -> String {
        var md = "# \(record.title)\n\n"
        md += "**기간**: \(formatDate(record.startDate)) ~ \(formatDate(record.endDate))\n\n"
        md += "---\n\n"

        for day in record.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            md += "## Day \(day.dayNumber)\n\n"
            for place in day.places.sorted(by: { $0.order < $1.order }) {
                let time = formatTime(place.startTime)
                md += "- **\(time)** - \(place.name) _(\(place.activityLabel))_\n"
            }
            md += "\n"
        }

        md += "---\n\n"
        md += "📊 **통계**\n"
        md += "- 이동거리: \(Int(record.totalDistance))km\n"
        md += "- 방문장소: \(record.placeCount)곳\n"
        md += "- 사진: \(record.photoCount)장\n"

        return md
    }

    private func generateHTMLExport() -> String {
        var html = "<html><head><meta charset='UTF-8'><title>\(record.title)</title></head><body>\n"
        html += "<h1>\(record.title)</h1>\n"
        html += "<p><strong>기간:</strong> \(formatDate(record.startDate)) ~ \(formatDate(record.endDate))</p>\n"
        html += "<hr>\n"

        for day in record.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            html += "<h2>Day \(day.dayNumber)</h2>\n<ul>\n"
            for place in day.places.sorted(by: { $0.order < $1.order }) {
                let time = formatTime(place.startTime)
                html += "  <li><strong>\(time)</strong> - \(place.name) <em>(\(place.activityLabel))</em></li>\n"
            }
            html += "</ul>\n"
        }

        html += "<hr>\n<h3>통계</h3>\n<ul>\n"
        html += "<li>이동거리: \(Int(record.totalDistance))km</li>\n"
        html += "<li>방문장소: \(record.placeCount)곳</li>\n"
        html += "<li>사진: \(record.photoCount)장</li>\n"
        html += "</ul>\n</body></html>"

        return html
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Record Edit View
struct RecordEditView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editedTitle: String
    @State private var showDeleteConfirmation = false

    init(record: TravelRecord) {
        self.record = record
        self._editedTitle = State(initialValue: record.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $editedTitle)

                    HStack {
                        Text("기간")
                        Spacer()
                        Text(formatDateRange())
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    HStack {
                        Text("유형")
                        Spacer()
                        Text(recordTypeLabel)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                }

                Section("통계") {
                    HStack {
                        Label("장소", systemImage: "mappin")
                        Spacer()
                        Text("\(record.placeCount)곳")
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    HStack {
                        Label("이동거리", systemImage: "car.fill")
                        Spacer()
                        Text(String(format: "%.1fkm", record.totalDistance))
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    HStack {
                        Label("사진", systemImage: "photo")
                        Spacer()
                        Text("\(record.photoCount)장")
                            .foregroundColor(WanderColors.textSecondary)
                    }
                }

                Section("타임라인") {
                    ForEach(record.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                        NavigationLink(destination: DayEditView(day: day)) {
                            HStack {
                                Text("Day \(day.dayNumber)")
                                    .font(WanderTypography.headline)
                                Spacer()
                                Text("\(day.places.count)곳")
                                    .font(WanderTypography.caption1)
                                    .foregroundColor(WanderColors.textSecondary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Label("기록 삭제", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(editedTitle.isEmpty)
                }
            }
            .confirmationDialog(
                "이 기록을 삭제하시겠습니까?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    deleteRecord()
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제된 기록은 복구할 수 없습니다.")
            }
        }
    }

    private var recordTypeLabel: String {
        switch record.recordType {
        case "travel": return "여행"
        case "daily": return "일상"
        case "weekly": return "주간"
        default: return "기록"
        }
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: record.startDate)) ~ \(formatter.string(from: record.endDate))"
    }

    private func saveChanges() {
        record.title = editedTitle
        record.updatedAt = Date()
        try? modelContext.save()
        logger.info("📝 [RecordEditView] 기록 저장됨: \(editedTitle)")
    }

    private func deleteRecord() {
        modelContext.delete(record)
        try? modelContext.save()
        logger.info("🗑️ [RecordEditView] 기록 삭제됨")
    }
}

// MARK: - Day Edit View
struct DayEditView: View {
    let day: TravelDay
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(day.places.sorted { $0.order < $1.order }) { place in
                NavigationLink(destination: PlaceEditView(place: place)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(WanderTypography.body)
                            Text(place.activityLabel)
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.textSecondary)
                        }
                        Spacer()
                        Text(formatTime(place.startTime))
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textTertiary)
                    }
                }
            }
            .onMove { from, to in
                var places = day.places.sorted { $0.order < $1.order }
                places.move(fromOffsets: from, toOffset: to)
                for (index, place) in places.enumerated() {
                    place.order = index
                }
                try? modelContext.save()
            }
        }
        .navigationTitle("Day \(day.dayNumber)")
        .toolbar {
            EditButton()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Place Edit View
struct PlaceEditView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editedName: String
    @State private var editedMemo: String
    @State private var editedActivityLabel: String

    init(place: Place) {
        self.place = place
        self._editedName = State(initialValue: place.name)
        self._editedMemo = State(initialValue: place.memo ?? "")
        self._editedActivityLabel = State(initialValue: place.activityLabel)
    }

    var body: some View {
        Form {
            Section("장소 정보") {
                TextField("이름", text: $editedName)

                HStack {
                    Text("주소")
                    Spacer()
                    Text(place.address)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("방문 시간")
                    Spacer()
                    Text(formatTime(place.startTime))
                        .foregroundColor(WanderColors.textSecondary)
                }
            }

            Section("활동 유형") {
                Picker("활동", selection: $editedActivityLabel) {
                    Text("카페").tag("카페")
                    Text("식사").tag("식사")
                    Text("해변").tag("해변")
                    Text("등산").tag("등산")
                    Text("관광").tag("관광")
                    Text("쇼핑").tag("쇼핑")
                    Text("문화").tag("문화")
                    Text("공항").tag("공항")
                    Text("기타").tag("기타")
                }
                .pickerStyle(.menu)
            }

            Section("메모") {
                TextEditor(text: $editedMemo)
                    .frame(minHeight: 100)
            }

            Section("사진") {
                HStack {
                    Text("등록된 사진")
                    Spacer()
                    Text("\(place.photos.count)장")
                        .foregroundColor(WanderColors.textSecondary)
                }
            }
        }
        .navigationTitle("장소 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    saveChanges()
                    dismiss()
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func saveChanges() {
        place.name = editedName
        place.memo = editedMemo.isEmpty ? nil : editedMemo
        place.activityLabel = editedActivityLabel

        // Update placeType based on activityLabel
        switch editedActivityLabel {
        case "카페": place.placeType = "cafe"
        case "식사": place.placeType = "restaurant"
        case "해변": place.placeType = "beach"
        case "등산": place.placeType = "mountain"
        case "관광": place.placeType = "tourist"
        case "쇼핑": place.placeType = "shopping"
        case "문화": place.placeType = "culture"
        case "공항": place.placeType = "airport"
        default: place.placeType = "other"
        }

        try? modelContext.save()
        logger.info("📝 [PlaceEditView] 장소 저장됨: \(editedName)")
    }
}

// MARK: - Record Map Sheet
struct RecordMapSheet: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic

    private var allPlaces: [Place] {
        record.days
            .sorted { $0.dayNumber < $1.dayNumber }
            .flatMap { $0.places.sorted { $0.order < $1.order } }
    }

    var body: some View {
        NavigationStack {
            Map(position: $camera) {
                ForEach(Array(allPlaces.enumerated()), id: \.element.id) { index, place in
                    Annotation(place.name, coordinate: place.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.2), radius: 4)

                            Circle()
                                .fill(WanderColors.primary)
                                .frame(width: 28, height: 28)

                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                if allPlaces.count > 1 {
                    MapPolyline(coordinates: allPlaces.map { $0.coordinate })
                        .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .mapStyle(.standard)
            .navigationTitle("여행 동선")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Record Photos Sheet
struct RecordPhotosSheet: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [UIImage] = []
    @State private var selectedPhotoIndex: Int?

    private var allPhotoAssetIds: [String] {
        record.allPhotoAssetIdentifiers
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if photos.isEmpty && !allPhotoAssetIds.isEmpty {
                    VStack(spacing: WanderSpacing.space4) {
                        ProgressView()
                        Text("사진 불러오는 중...")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else if photos.isEmpty {
                    VStack(spacing: WanderSpacing.space4) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(WanderColors.textTertiary)
                        Text("사진이 없습니다")
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ], spacing: 2) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Button(action: { selectedPhotoIndex = index }) {
                                Image(uiImage: photos[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                            }
                        }
                    }
                }
            }
            .navigationTitle("사진 \(record.photoCount)장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .onAppear {
                loadPhotos()
            }
            .fullScreenCover(item: Binding(
                get: { selectedPhotoIndex.map { PhotoViewerItem(index: $0) } },
                set: { selectedPhotoIndex = $0?.index }
            )) { item in
                PhotoViewer(photos: photos, initialIndex: item.index)
            }
        }
    }

    private func loadPhotos() {
        guard !allPhotoAssetIds.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: allPhotoAssetIds, options: nil)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false

        var loadedImages: [UIImage] = []
        var pendingCount = fetchResult.count

        fetchResult.enumerateObjects { asset, _, _ in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    if let image = image {
                        loadedImages.append(image)
                    }
                    pendingCount -= 1
                    if pendingCount == 0 {
                        self.photos = loadedImages
                    }
                }
            }
        }
    }
}

#Preview {
    RecordsView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
