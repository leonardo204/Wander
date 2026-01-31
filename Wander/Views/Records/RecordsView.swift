import SwiftUI
import SwiftData

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
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: start)) ~ \(formatter.string(from: end))"
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
    @State private var showShareSheet = false
    @State private var showAIStorySheet = false

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showShareSheet = true }) {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { showAIStorySheet = true }) {
                        Label("AI 스토리 생성", systemImage: "sparkles")
                    }
                    Button(action: {}) {
                        Label("편집", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ExportOptionsView(record: record)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAIStorySheet) {
            AIStoryView(record: record)
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
            StatCard(icon: "mappin.circle.fill", value: "\(record.placeCount)", label: "장소")
            StatCard(icon: "car.fill", value: String(format: "%.1f", record.totalDistance), label: "km")
            StatCard(icon: "photo.fill", value: "\(record.photoCount)", label: "사진")
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

    var body: some View {
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

                Text(place.activityLabel)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, WanderSpacing.space2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Export Options View (Placeholder)
struct ExportOptionsView: View {
    let record: TravelRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("공유 형식") {
                    Button(action: {}) {
                        Label("텍스트로 공유", systemImage: "doc.text")
                    }
                    Button(action: {}) {
                        Label("이미지로 공유", systemImage: "photo")
                    }
                    Button(action: {}) {
                        Label("Markdown으로 내보내기", systemImage: "doc.richtext")
                    }
                }
            }
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RecordsView()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
