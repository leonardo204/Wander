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
    @State private var showHiddenRecords = false

    /// 숨기지 않은 기록만 반환
    var visibleRecords: [TravelRecord] {
        records.filter { !$0.isHidden }
    }

    /// 숨긴 기록 개수
    var hiddenRecordsCount: Int {
        records.filter { $0.isHidden }.count
    }

    var filteredRecords: [TravelRecord] {
        var result = visibleRecords

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .travel:
            result = result.filter { $0.category?.name == "여행" || $0.category == nil }
        case .daily:
            result = result.filter { $0.category?.name == "일상" }
        case .weekly:
            result = result.filter { $0.category?.name == "주간" }
        case .business:
            result = result.filter { $0.category?.name == "출장" }
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
            .sheet(isPresented: $showHiddenRecords) {
                HiddenRecordsView()
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
                        Button {
                            hideRecord(record)
                        } label: {
                            Label("숨기기", systemImage: "eye.slash")
                        }

                        Button(role: .destructive) {
                            recordToDelete = record
                            showDeleteConfirmation = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }

                // 숨긴 기록 섹션
                if hiddenRecordsCount > 0 {
                    hiddenRecordsSection
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space4)
        }
    }

    // MARK: - Hidden Records Section
    private var hiddenRecordsSection: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.vertical, WanderSpacing.space4)

            Button(action: { showHiddenRecords = true }) {
                HStack(spacing: WanderSpacing.space3) {
                    ZStack {
                        Circle()
                            .fill(WanderColors.surface)
                            .frame(width: 44, height: 44)

                        Image(systemName: "eye.slash")
                            .font(.system(size: 18))
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("숨긴 기록")
                            .font(WanderTypography.headline)
                            .foregroundColor(WanderColors.textPrimary)

                        Text("\(hiddenRecordsCount)개의 기록이 숨겨져 있습니다")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(WanderColors.textTertiary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
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

    // MARK: - Helper Functions
    private func countForFilter(_ filter: RecordFilter) -> Int {
        switch filter {
        case .all:
            return visibleRecords.count
        case .travel:
            return visibleRecords.filter { $0.category?.name == "여행" || $0.category == nil }.count
        case .daily:
            return visibleRecords.filter { $0.category?.name == "일상" }.count
        case .weekly:
            return visibleRecords.filter { $0.category?.name == "주간" }.count
        case .business:
            return visibleRecords.filter { $0.category?.name == "출장" }.count
        }
    }

    private func hideRecord(_ record: TravelRecord) {
        record.isHidden = true
        record.updatedAt = Date()
        try? modelContext.save()
        logger.info("🙈 [RecordsView] 기록 숨김: \(record.title)")
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
    case business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "전체"
        case .travel: return "여행"
        case .daily: return "일상"
        case .weekly: return "주간"
        case .business: return "출장"
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
                RecordCategoryBadge(category: record.category)
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

// MARK: - Record Category Badge
struct RecordCategoryBadge: View {
    let category: RecordCategory?

    var body: some View {
        HStack(spacing: 4) {
            Text(category?.icon ?? "✈️")
                .font(.system(size: 12))
            Text(category?.name ?? "여행")
        }
        .font(WanderTypography.caption2)
        .foregroundColor(WanderColors.textSecondary)
        .padding(.horizontal, WanderSpacing.space2)
        .padding(.vertical, WanderSpacing.space1)
        .background(category?.color.opacity(0.15) ?? WanderColors.primaryPale)
        .cornerRadius(WanderSpacing.radiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: WanderSpacing.radiusSmall)
                .stroke(category?.color.opacity(0.3) ?? WanderColors.border, lineWidth: 1)
        )
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
    @State private var showHideConfirmation = false

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

                // Share Button (at bottom)
                shareButton
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
                    Button(action: { showAIStorySheet = true }) {
                        Label("AI 스토리 생성", systemImage: "sparkles")
                    }
                    Button(action: { showEditSheet = true }) {
                        Label("편집", systemImage: "pencil")
                    }

                    Divider()

                    Button(action: { showHideConfirmation = true }) {
                        Label(record.isHidden ? "숨김 해제" : "숨기기", systemImage: record.isHidden ? "eye" : "eye.slash")
                    }

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
        .confirmationDialog(
            record.isHidden ? "이 기록을 다시 표시하시겠습니까?" : "이 기록을 숨기시겠습니까?",
            isPresented: $showHideConfirmation,
            titleVisibility: .visible
        ) {
            Button(record.isHidden ? "숨김 해제" : "숨기기") {
                toggleHideRecord()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(record.isHidden ? "기록 목록에 다시 표시됩니다." : "숨긴 기록은 별도 섹션에서 확인할 수 있습니다.")
        }
        .sheet(isPresented: $showShareSheet) {
            RecordShareSheetView(record: record)
                .presentationDetents([.large])
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

    // MARK: - Share Button
    private var shareButton: some View {
        Button(action: { showShareSheet = true }) {
            HStack(spacing: WanderSpacing.space2) {
                Image(systemName: "square.and.arrow.up")
                Text("공유하기")
            }
            .font(WanderTypography.headline)
            .foregroundColor(WanderColors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: WanderSpacing.buttonHeight)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                    .stroke(WanderColors.primary, lineWidth: 1)
            )
        }
        .padding(.top, WanderSpacing.space4)
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

    private func toggleHideRecord() {
        record.isHidden.toggle()
        record.updatedAt = Date()
        try? modelContext.save()
        logger.info("🙈 [RecordDetailFullView] 기록 숨김 상태 변경: \(record.title) → \(record.isHidden ? "숨김" : "표시")")
        if record.isHidden {
            dismiss()
        }
    }
}

// MARK: - Day Section
struct DaySection: View {
    let day: TravelDay

    var body: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Day header (실제 날짜)
            Text(formatDateWithWeekday(day.date))
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

    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
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
                    Image(uiImage: photos[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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

// MARK: - Record Share Sheet View (Format Selection → Preview → Share)
struct RecordShareSheetView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: RecordShareFormat = .image
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space5) {
                // Header
                VStack(spacing: WanderSpacing.space2) {
                    Text("공유 형식 선택")
                        .font(WanderTypography.title3)
                        .foregroundColor(WanderColors.textPrimary)

                    Text("형식을 선택한 후 미리보기를 확인하세요")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                }
                .padding(.top, WanderSpacing.space4)

                // Format Selection
                VStack(spacing: WanderSpacing.space3) {
                    ForEach(RecordShareFormat.allCases) { format in
                        RecordShareFormatCard(
                            format: format,
                            isSelected: selectedFormat == format,
                            onSelect: { selectedFormat = format }
                        )
                    }
                }

                Spacer()

                // Next Button
                Button(action: { showPreview = true }) {
                    HStack {
                        Text("미리보기")
                        Image(systemName: "chevron.right")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
            }
            .padding(WanderSpacing.screenMargin)
            .navigationTitle("공유하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showPreview) {
                RecordSharePreviewView(record: record, format: selectedFormat, onDismissAll: { dismiss() })
            }
        }
    }
}

// MARK: - Record Share Format
enum RecordShareFormat: String, CaseIterable, Identifiable {
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "텍스트"
        case .image: return "이미지"
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        }
    }

    var description: String {
        switch self {
        case .text: return "타임라인을 텍스트로 공유"
        case .image: return "1080×1920 세로형 이미지"
        }
    }
}

// MARK: - Record Share Format Card
struct RecordShareFormatCard: View {
    let format: RecordShareFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WanderSpacing.space4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? WanderColors.primary : WanderColors.surface)
                        .frame(width: 48, height: 48)

                    Image(systemName: format.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(format.title)
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(format.description)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.primary)
                } else {
                    Circle()
                        .stroke(WanderColors.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(WanderSpacing.space4)
            .background(isSelected ? WanderColors.primaryPale : WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                    .stroke(isSelected ? WanderColors.primary : WanderColors.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Share Preview View
struct RecordSharePreviewView: View {
    let record: TravelRecord
    let format: RecordShareFormat
    let onDismissAll: () -> Void

    @State private var isLoading = true
    @State private var previewImages: [UIImage] = []
    @State private var previewText: String = ""
    @State private var isSharing = false
    @State private var currentImageIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: WanderSpacing.space4) {
                    if isLoading {
                        loadingView
                    } else {
                        switch format {
                        case .text:
                            textPreview
                        case .image:
                            imagePreview
                        }
                    }
                }
                .padding(WanderSpacing.screenMargin)
            }

            // Bottom Bar
            VStack(spacing: WanderSpacing.space3) {
                Button(action: performShare) {
                    HStack {
                        if isSharing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isSharing ? "공유 준비 중..." : "공유하기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(isLoading || isSharing ? WanderColors.textTertiary : WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(isLoading || isSharing)
            }
            .padding(WanderSpacing.screenMargin)
            .background(WanderColors.surface)
        }
        .background(WanderColors.background)
        .navigationTitle("미리보기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("닫기") {
                    onDismissAll()
                }
                .foregroundColor(WanderColors.textSecondary)
            }
        }
        .onAppear {
            generatePreview()
        }
    }

    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer().frame(height: 100)
            ProgressView().scaleEffect(1.5)
            Text("미리보기 생성 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
            Spacer().frame(height: 100)
        }
        .frame(maxWidth: .infinity)
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Image(systemName: "doc.text")
                Text("텍스트 미리보기")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)

            Text(previewText)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(WanderColors.textPrimary)
                .padding(WanderSpacing.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
        }
    }

    private var imagePreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                if previewImages.count > 1 {
                    Text("이미지 \(currentImageIndex + 1)/\(previewImages.count) (1080×1920)")
                } else {
                    Text("이미지 미리보기 (1080×1920)")
                }
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)

            if !previewImages.isEmpty {
                TabView(selection: $currentImageIndex) {
                    ForEach(previewImages.indices, id: \.self) { index in
                        Image(uiImage: previewImages[index])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(WanderSpacing.radiusLarge)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: previewImages.count > 1 ? .automatic : .never))
                .frame(height: 500)
            }
        }
    }

    private func generatePreview() {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            switch format {
            case .text:
                let text = generateTextFromRecord()
                await MainActor.run {
                    previewText = text
                    isLoading = false
                }

            case .image:
                let images = await generateImagesFromRecord()
                await MainActor.run {
                    previewImages = images
                    isLoading = false
                }
            }
        }
    }

    private func generateTextFromRecord() -> String {
        var text = "\(record.title)\n\n"
        text += "📅 \(formatDate(record.startDate)) ~ \(formatDate(record.endDate))\n"
        text += "📍 \(record.placeCount)개 장소 | 📸 \(record.photoCount)장 | 🚗 \(String(format: "%.1f", record.totalDistance))km\n\n"
        text += "--- 타임라인 ---\n"

        for day in record.days.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            text += "\n━━━ \(formatDateWithWeekday(day.date)) ━━━\n\n"
            for (index, place) in day.places.sorted(by: { $0.order < $1.order }).enumerated() {
                let time = formatTime(place.startTime)
                text += "[\(index + 1)] \(time)\n"
                text += "\(place.name)\n"
                text += "📍 \(place.activityLabel)\n\n"
            }
        }

        text += "---\n🗺️ Wander로 기록했어요"

        return text
    }

    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func generateImagesFromRecord() async -> [UIImage] {
        // Load thumbnails for ALL days
        let photosByDay = await loadAllThumbnailsByDay()
        var thumbnailsByDayNumber: [Int: [UIImage]] = [:]
        for dayData in photosByDay {
            thumbnailsByDayNumber[dayData.dayNumber] = dayData.thumbnails
        }

        let size = CGSize(width: 1080, height: 1920)
        let sortedDays = record.days.sorted { $0.dayNumber < $1.dayNumber }

        // 레이아웃 상수
        let headerHeight: CGFloat = 440  // 제목 + 날짜 + 통계 + 타임라인 제목
        let continueHeaderHeight: CGFloat = 120  // 이어서 표시 헤더
        let watermarkHeight: CGFloat = 80
        let dayHeaderHeight: CGFloat = 42
        let placeHeight: CGFloat = 95
        let photoRowHeight: CGFloat = 170
        let daySpacing: CGFloat = 30
        let maxPlacesPerDay = 3

        // 각 페이지에 들어갈 Day 계산
        var pages: [[TravelDay]] = []
        var currentPage: [TravelDay] = []
        var currentPageHeight: CGFloat = headerHeight  // 첫 페이지는 헤더 포함

        for day in sortedDays {
            let placesCount = min(day.places.count, maxPlacesPerDay)
            let hasMorePlaces = day.places.count > maxPlacesPerDay
            let hasPhotos = thumbnailsByDayNumber[day.dayNumber] != nil

            var dayHeight = dayHeaderHeight
            dayHeight += CGFloat(placesCount) * placeHeight
            if hasMorePlaces { dayHeight += 30 }  // "외 X곳 더" 텍스트
            if hasPhotos { dayHeight += photoRowHeight }
            dayHeight += daySpacing

            let maxPageHeight = size.height - watermarkHeight

            if currentPageHeight + dayHeight > maxPageHeight && !currentPage.isEmpty {
                // 현재 페이지 마감, 새 페이지 시작
                pages.append(currentPage)
                currentPage = [day]
                currentPageHeight = continueHeaderHeight + dayHeight
            } else {
                currentPage.append(day)
                currentPageHeight += dayHeight
            }
        }

        // 마지막 페이지 추가
        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        // 이미지 생성
        var images: [UIImage] = []
        let totalPages = pages.count

        for (pageIndex, pageDays) in pages.enumerated() {
            let isFirstPage = pageIndex == 0
            let renderer = UIGraphicsImageRenderer(size: size)

            let image = renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                UIColor.white.setFill()
                context.fill(rect)

                var currentY: CGFloat = 0

                if isFirstPage {
                    // 첫 페이지: 전체 헤더 그리기
                    drawFirstPageHeader(size: size)
                    currentY = headerHeight
                } else {
                    // 이어지는 페이지: 간단한 헤더
                    drawContinueHeader(pageNumber: pageIndex + 1, totalPages: totalPages, size: size)
                    currentY = continueHeaderHeight
                }

                // Day 컨텐츠 그리기
                currentY = drawDaysContent(
                    days: pageDays,
                    thumbnailsByDayNumber: thumbnailsByDayNumber,
                    startY: currentY,
                    size: size,
                    maxPlacesPerDay: maxPlacesPerDay
                )

                // 워터마크
                drawWatermarkAt(size: size)
            }

            images.append(image)
        }

        return images
    }

    // MARK: - Drawing Helper Functions

    private func drawFirstPageHeader(size: CGSize) {
        let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let dateFont = UIFont.systemFont(ofSize: 28, weight: .regular)
        let dateColor = UIColor(red: 0.35, green: 0.42, blue: 0.45, alpha: 1)

        // Title
        let titleRect = CGRect(x: 60, y: 80, width: size.width - 120, height: 70)
        let titleString = NSAttributedString(
            string: record.title,
            attributes: [.font: titleFont, .foregroundColor: titleColor]
        )
        titleString.draw(in: titleRect)

        // Date
        let dateRect = CGRect(x: 60, y: 160, width: size.width - 120, height: 40)
        let dateString = NSAttributedString(
            string: "📅 \(formatDate(record.startDate)) ~ \(formatDate(record.endDate))",
            attributes: [.font: dateFont, .foregroundColor: dateColor]
        )
        dateString.draw(in: dateRect)

        // Stats
        let statsY: CGFloat = 240
        let statsRect = CGRect(x: 40, y: statsY, width: size.width - 80, height: 150)
        let statsPath = UIBezierPath(roundedRect: statsRect, cornerRadius: 24)
        UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1).setFill()
        statsPath.fill()

        let statFont = UIFont.systemFont(ofSize: 36, weight: .bold)
        let labelFont = UIFont.systemFont(ofSize: 20, weight: .regular)
        let statColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let labelColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 1)

        let stats = [
            ("📍", "\(record.placeCount)", "방문 장소"),
            ("📸", "\(record.photoCount)", "사진"),
            ("🚗", String(format: "%.1f", record.totalDistance), "km")
        ]

        let statWidth = (size.width - 80) / 3
        for (index, stat) in stats.enumerated() {
            let x = 40 + CGFloat(index) * statWidth
            let centerX = x + statWidth / 2

            let valueString = NSAttributedString(
                string: "\(stat.0) \(stat.1)",
                attributes: [.font: statFont, .foregroundColor: statColor]
            )
            let valueSize = valueString.size()
            valueString.draw(at: CGPoint(x: centerX - valueSize.width / 2, y: statsY + 35))

            let labelString = NSAttributedString(
                string: stat.2,
                attributes: [.font: labelFont, .foregroundColor: labelColor]
            )
            let labelSize = labelString.size()
            labelString.draw(at: CGPoint(x: centerX - labelSize.width / 2, y: statsY + 95))
        }

        // Timeline title
        let sectionFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let sectionTitle = NSAttributedString(
            string: "타임라인",
            attributes: [.font: sectionFont, .foregroundColor: titleColor]
        )
        sectionTitle.draw(at: CGPoint(x: 60, y: 440 - 60))
    }

    private func drawContinueHeader(pageNumber: Int, totalPages: Int, size: CGSize) {
        let titleFont = UIFont.systemFont(ofSize: 36, weight: .bold)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let subtitleFont = UIFont.systemFont(ofSize: 20, weight: .regular)
        let subtitleColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 1)

        // 제목 (이어서)
        let titleString = NSAttributedString(
            string: record.title,
            attributes: [.font: titleFont, .foregroundColor: titleColor]
        )
        titleString.draw(at: CGPoint(x: 60, y: 50))

        // 페이지 표시
        let pageString = NSAttributedString(
            string: "타임라인 (\(pageNumber)/\(totalPages))",
            attributes: [.font: subtitleFont, .foregroundColor: subtitleColor]
        )
        pageString.draw(at: CGPoint(x: 60, y: 95))
    }

    private func drawDaysContent(
        days: [TravelDay],
        thumbnailsByDayNumber: [Int: [UIImage]],
        startY: CGFloat,
        size: CGSize,
        maxPlacesPerDay: Int
    ) -> CGFloat {
        var currentY = startY

        let dayHeaderFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let placeFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let timeFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let addressFont = UIFont.systemFont(ofSize: 13, weight: .regular)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let dateColor = UIColor(red: 0.35, green: 0.42, blue: 0.45, alpha: 1)
        let primaryColor = UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1)
        let primaryPaleColor = UIColor(red: 0.91, green: 0.96, blue: 0.99, alpha: 1)
        let timeColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 1)

        for day in days {
            // Day header
            let dayHeaderRect = CGRect(x: 60, y: currentY, width: 150, height: 30)
            let dayHeaderPath = UIBezierPath(roundedRect: dayHeaderRect, cornerRadius: 8)
            primaryPaleColor.setFill()
            dayHeaderPath.fill()

            let dayString = NSAttributedString(
                string: formatDateWithWeekday(day.date),
                attributes: [.font: dayHeaderFont, .foregroundColor: primaryColor]
            )
            let dayStringSize = dayString.size()
            dayString.draw(at: CGPoint(
                x: dayHeaderRect.minX + 8,
                y: dayHeaderRect.midY - dayStringSize.height / 2
            ))

            currentY += 42

            // Places
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            for (placeIndex, place) in sortedPlaces.prefix(maxPlacesPerDay).enumerated() {
                let isLastInDay = placeIndex == min(sortedPlaces.count, maxPlacesPerDay) - 1

                // Number circle
                let circleRect = CGRect(x: 60, y: currentY, width: 36, height: 36)
                let circlePath = UIBezierPath(ovalIn: circleRect)
                primaryColor.setFill()
                circlePath.fill()

                let numberString = NSAttributedString(
                    string: "\(placeIndex + 1)",
                    attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: UIColor.white]
                )
                let numberSize = numberString.size()
                numberString.draw(at: CGPoint(x: circleRect.midX - numberSize.width / 2, y: circleRect.midY - numberSize.height / 2))

                // Connector line
                if !isLastInDay {
                    let linePath = UIBezierPath()
                    linePath.move(to: CGPoint(x: 78, y: currentY + 36))
                    linePath.addLine(to: CGPoint(x: 78, y: currentY + 85))
                    UIColor(red: 0.9, green: 0.93, blue: 0.95, alpha: 1).setStroke()
                    linePath.lineWidth = 2
                    linePath.stroke()
                }

                // Time
                let timeString = NSAttributedString(
                    string: formatTime(place.startTime),
                    attributes: [.font: timeFont, .foregroundColor: timeColor]
                )
                timeString.draw(at: CGPoint(x: 110, y: currentY - 2))

                // Place name
                var displayName = "\(place.activityLabel) \(place.name)"
                if displayName.count > 30 {
                    displayName = String(displayName.prefix(30)) + "..."
                }
                let placeString = NSAttributedString(
                    string: displayName,
                    attributes: [.font: placeFont, .foregroundColor: titleColor]
                )
                placeString.draw(at: CGPoint(x: 110, y: currentY + 15))

                // Address
                var displayAddress = place.address
                if displayAddress.count > 42 {
                    displayAddress = String(displayAddress.prefix(42)) + "..."
                }
                let addressString = NSAttributedString(
                    string: "📍 \(displayAddress)",
                    attributes: [.font: addressFont, .foregroundColor: dateColor]
                )
                addressString.draw(at: CGPoint(x: 110, y: currentY + 40))

                currentY += 95
            }

            // "외 X곳 더" 표시
            if sortedPlaces.count > maxPlacesPerDay {
                let moreString = NSAttributedString(
                    string: "외 \(sortedPlaces.count - maxPlacesPerDay)곳 더",
                    attributes: [.font: addressFont, .foregroundColor: timeColor]
                )
                moreString.draw(at: CGPoint(x: 110, y: currentY - 10))
                currentY += 20
            }

            // Photos
            if let thumbnails = thumbnailsByDayNumber[day.dayNumber], !thumbnails.isEmpty {
                currentY += 5
                currentY = drawDayPhotosInline(thumbnails: thumbnails, startY: currentY, size: size)
            }

            currentY += 30
        }

        return currentY
    }

    private func drawWatermarkAt(size: CGSize) {
        let watermarkFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let watermarkColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 0.8)
        let watermarkString = NSAttributedString(
            string: "🗺️ Wander",
            attributes: [.font: watermarkFont, .foregroundColor: watermarkColor]
        )
        let watermarkSize = watermarkString.size()
        watermarkString.draw(at: CGPoint(x: size.width - watermarkSize.width - 40, y: size.height - watermarkSize.height - 40))
    }

    /// Draw photos for a single day (horizontal row)
    private func drawDayPhotosInline(thumbnails: [UIImage], startY: CGFloat, size: CGSize) -> CGFloat {
        let margin: CGFloat = 60
        let spacing: CGFloat = 10
        let availableWidth = size.width - (margin * 2)
        let cornerRadius: CGFloat = 12

        var currentY = startY
        let photoCount = thumbnails.count

        if photoCount == 1 {
            let photoWidth = availableWidth * 0.55
            let photoHeight: CGFloat = 160
            let photoRect = CGRect(x: margin, y: currentY, width: photoWidth, height: photoHeight)
            drawRoundedImage(thumbnails[0], in: photoRect, cornerRadius: cornerRadius)
            currentY += photoHeight
        } else {
            let photoWidth = (availableWidth - spacing * CGFloat(photoCount - 1)) / CGFloat(photoCount)
            let photoHeight: CGFloat = 150

            for (index, thumbnail) in thumbnails.enumerated() {
                let x = margin + CGFloat(index) * (photoWidth + spacing)
                let rect = CGRect(x: x, y: currentY, width: photoWidth, height: photoHeight)
                drawRoundedImage(thumbnail, in: rect, cornerRadius: cornerRadius)
            }
            currentY += photoHeight
        }

        return currentY
    }

    /// 모든 Day의 썸네일 로드 (분할 이미지 생성용)
    private func loadAllThumbnailsByDay() async -> [(dayNumber: Int, date: Date, thumbnails: [UIImage])] {
        var result: [(dayNumber: Int, date: Date, thumbnails: [UIImage])] = []

        let maxPhotosPerDay = 3

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        let targetSize = CGSize(width: 400, height: 400)

        let sortedDays = record.days.sorted { $0.dayNumber < $1.dayNumber }

        for day in sortedDays {  // 모든 Day 로드
            let assetIds = day.places
                .flatMap { $0.photos }
                .prefix(maxPhotosPerDay)
                .compactMap { $0.assetIdentifier }

            guard !assetIds.isEmpty else { continue }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(assetIds), options: nil)
            var thumbnails: [UIImage] = []

            fetchResult.enumerateObjects { asset, _, _ in
                let semaphore = DispatchSemaphore(value: 0)
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        thumbnails.append(image)
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }

            if !thumbnails.isEmpty {
                result.append((dayNumber: day.dayNumber, date: day.date, thumbnails: thumbnails))
            }
        }

        return result
    }

    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        UIGraphicsGetCurrentContext()?.saveGState()
        path.addClip()

        // Calculate aspect fill
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height

        var drawRect = rect
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight / 2,
                width: rect.width,
                height: scaledHeight
            )
        }

        image.draw(in: drawRect)
        UIGraphicsGetCurrentContext()?.restoreGState()

        // Draw subtle border
        UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func performShare() {
        isSharing = true

        Task {
            var items: [Any] = []

            switch format {
            case .text:
                items = [previewText]
            case .image:
                // 이미지를 임시 파일로 저장 후 URL로 공유 (카카오톡 등 외부 앱 호환성 향상)
                let tempDir = FileManager.default.temporaryDirectory
                for (index, image) in previewImages.enumerated() {
                    if let jpegData = image.jpegData(compressionQuality: 0.85) {
                        let fileName = "wander_share_\(index + 1).jpg"
                        let fileURL = tempDir.appendingPathComponent(fileName)
                        do {
                            try jpegData.write(to: fileURL)
                            items.append(fileURL)
                        } catch {
                            // 파일 저장 실패 시 이미지 직접 추가
                            items.append(image)
                        }
                    } else {
                        items.append(image)
                    }
                }
            }

            await MainActor.run {
                guard !items.isEmpty else {
                    isSharing = false
                    return
                }

                showActivitySheet(with: items)
            }
        }
    }

    private func showActivitySheet(with items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            isSharing = false
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            isSharing = false
            if completed {
                onDismissAll()
            }
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.maxY - 100, width: 0, height: 0)
            popover.permittedArrowDirections = .down
        }

        topVC.present(activityVC, animated: true)
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
                        Text("카테고리")
                        Spacer()
                        HStack(spacing: 4) {
                            Text(record.categoryIcon)
                            Text(record.categoryName)
                        }
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
                                Text(formatDayDate(day.date))
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

    private func formatDayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
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
        .navigationTitle(formatDayDate(day.date))
        .toolbar {
            EditButton()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
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
