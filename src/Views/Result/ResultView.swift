import SwiftUI
import MapKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ResultView")

struct ResultView: View {
    @State private var result: AnalysisResult
    let selectedAssets: [PHAsset]
    var onSaveComplete: ((TravelRecord) -> Void)?
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var isSaved = false
    @State private var savedRecord: TravelRecord?

    // P2P 공유
    @State private var showP2PShareOptions = false
    @State private var pendingP2PShareResult: P2PShareResult?  // onDismiss에서 사용할 임시 저장소
    @State private var p2pShareResultWrapper: P2PShareResultWrapper?

    // AI 다듬기
    @State private var showAIEnhancement = false
    @State private var isEnhancing = false
    @State private var enhancementError: String?

    init(result: AnalysisResult, selectedAssets: [PHAsset], onSaveComplete: ((TravelRecord) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self._result = State(initialValue: result)
        self.selectedAssets = selectedAssets
        self.onSaveComplete = onSaveComplete
        self.onDismiss = onDismiss
        logger.info("📊 [ResultView] init - 제목: \(result.title), 장소: \(result.places.count)개")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // Map Section
                    mapSection

                    // Stats Section
                    statsSection

                    // Wander Intelligence Sections
                    if result.tripScore != nil || result.travelDNA != nil {
                        wanderIntelligenceSection
                    }

                    // Timeline Section
                    timelineSection

                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
            .background(WanderColors.background)
            .navigationTitle(result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        logger.info("📊 [ResultView] 취소 버튼 클릭 - 저장됨: \(isSaved)")
                        // onDismiss 콜백 → 홈 화면으로 복귀
                        onDismiss?()
                    }
                }

                // NOTE: 공유는 저장 후에만 가능 - 저장 전에는 아이콘 미표시
                ToolbarItem(placement: .primaryAction) {
                    if isSaved {
                        Menu {
                            Button(action: { showShareSheet = true }) {
                                Label("일반 이미지 공유", systemImage: "square.and.arrow.up")
                            }

                            Button(action: { showP2PShareOptions = true }) {
                                Label("Wander 공유", systemImage: "link.badge.plus")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let record = savedRecord {
                    ShareFlowView(record: record)
                }
            }
            // P2P 공유 옵션 시트
            .sheet(isPresented: $showP2PShareOptions, onDismiss: {
                // 시트가 완전히 닫힌 후 pending 결과가 있으면 완료 화면 표시
                if let result = pendingP2PShareResult {
                    pendingP2PShareResult = nil
                    p2pShareResultWrapper = P2PShareResultWrapper(result: result)
                }
            }) {
                if let record = savedRecord {
                    P2PShareOptionsView(record: record) { result in
                        // 결과를 임시 저장하고 시트 닫기
                        pendingP2PShareResult = result
                        showP2PShareOptions = false
                    }
                }
            }
            // P2P 공유 완료 시트 (onDismiss 콜백 후 표시)
            .sheet(item: $p2pShareResultWrapper) { wrapper in
                P2PShareCompleteView(shareResult: wrapper.result) {
                    p2pShareResultWrapper = nil
                }
            }
            .onAppear {
                logger.info("📊 [ResultView] onAppear - 화면 표시됨")
                logger.info("📊 [ResultView] result.title: \(result.title)")
                logger.info("📊 [ResultView] result.places.count: \(result.places.count)")
                logger.info("📊 [ResultView] result.photoCount: \(result.photoCount)")
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 동선")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // 유효한 좌표가 있는 장소만 지도에 표시 (미분류 사진 제외)
                let validPlaces = result.places.filter { $0.hasValidCoordinate }
                NavigationLink(destination: MapDetailView(places: validPlaces)) {
                    HStack(spacing: WanderSpacing.space1) {
                        Text("전체 보기")
                            .font(WanderTypography.caption1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WanderColors.primary)
                }
            }

            // Mini Map - 유효한 좌표가 있는 장소만 표시
            let validPlacesForMap = result.places.filter { $0.hasValidCoordinate }
            Map {
                ForEach(Array(validPlacesForMap.enumerated()), id: \.element.id) { index, place in
                    Annotation("", coordinate: place.coordinate) {
                        PlaceMarker(number: index + 1, activityType: place.activityType)
                    }
                }

                if validPlacesForMap.count > 1 {
                    MapPolyline(coordinates: validPlacesForMap.map { $0.coordinate })
                        .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(WanderSpacing.radiusLarge)
            .disabled(true) // Make it non-interactive for preview
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            // 분석 레벨 배지 (스마트 분석인 경우)
            if let badge = result.analysisLevelBadge {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: result.smartAnalysisResult?.analysisLevel == .advanced ? "brain" : "sparkles")
                        .font(.system(size: 14))
                    Text(badge)
                        .font(WanderTypography.caption1)

                    // 분석 통계
                    if let smart = result.smartAnalysisResult {
                        Text("·")
                        Text("장면 \(smart.visionClassificationCount)장 분석")
                            .font(WanderTypography.caption2)
                    }
                }
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space2)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)
            }

            // 기본 통계 카드
            HStack(spacing: WanderSpacing.space4) {
                StatCard(
                    icon: "mappin.circle.fill",
                    value: "\(result.placeCount)",
                    label: "방문 장소"
                )

                StatCard(
                    icon: "car.fill",
                    value: String(format: "%.1f", result.totalDistance),
                    label: "이동 거리 (km)"
                )

                StatCard(
                    icon: "photo.fill",
                    value: "\(result.photoCount)",
                    label: "사진"
                )
            }

            // 서브타이틀 (스마트 분석 결과)
            Text(result.subtitle)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
    }

    // MARK: - Wander Intelligence Section
    @ViewBuilder
    private var wanderIntelligenceSection: some View {
        VStack(spacing: WanderSpacing.space5) {
            // Trip Score Card
            if let tripScore = result.tripScore {
                tripScoreCard(tripScore)
            }

            // Travel DNA Card
            if let dna = result.travelDNA {
                travelDNACard(dna)
            }

            // Insights Preview
            if !result.insights.isEmpty {
                insightsPreview
            }

            // Story Preview
            if let story = result.travelStory {
                storyPreviewCard(story)
            }
        }
    }

    // MARK: - Trip Score Card
    private func tripScoreCard(_ tripScore: MomentScoreService.TripOverallScore) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 점수")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // Star Rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(tripScore.starRating) ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(WanderColors.warning)
                    }
                }
            }

            HStack(spacing: WanderSpacing.space4) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(WanderColors.border, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(tripScore.averageScore) / 100)
                        .stroke(gradeColor(for: tripScore.tripGrade), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(tripScore.averageScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(WanderColors.textPrimary)
                        Text("점")
                            .font(WanderTypography.caption2)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    // Grade Badge
                    HStack(spacing: WanderSpacing.space1) {
                        Text(tripScore.tripGrade.emoji)
                        Text(tripScore.tripGrade.koreanName)
                            .font(WanderTypography.headline)
                    }
                    .foregroundColor(gradeColor(for: tripScore.tripGrade))

                    // Summary
                    Text(tripScore.summary)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(2)

                    // Peak Moment
                    if tripScore.peakMomentScore > tripScore.averageScore {
                        Text("최고 순간: \(tripScore.peakMomentScore)점")
                            .font(WanderTypography.caption2)
                            .foregroundColor(WanderColors.primary)
                    }
                }

                Spacer()
            }

            // Badges
            if !result.allBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(result.allBadges, id: \.self) { badge in
                            HStack(spacing: 4) {
                                Text(badge.emoji)
                                Text(badge.koreanName)
                                    .font(WanderTypography.caption2)
                            }
                            .padding(.horizontal, WanderSpacing.space2)
                            .padding(.vertical, 4)
                            .background(WanderColors.primaryPale)
                            .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Travel DNA Card
    private func travelDNACard(_ dna: TravelDNAService.TravelDNA) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행자 DNA")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                // DNA Code
                Text(dna.dnaCode)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(WanderColors.primary)
                    .padding(.horizontal, WanderSpacing.space2)
                    .padding(.vertical, 4)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusSmall)
            }

            HStack(spacing: WanderSpacing.space4) {
                // Primary Type Icon
                VStack(spacing: WanderSpacing.space2) {
                    ZStack {
                        Circle()
                            .fill(WanderColors.primaryPale)
                            .frame(width: 60, height: 60)

                        Text(dna.primaryType.emoji)
                            .font(.system(size: 28))
                    }

                    Text(dna.primaryType.koreanName)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    // Description
                    Text(dna.description)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(2)

                    // Stats
                    HStack(spacing: WanderSpacing.space3) {
                        DNAStatChip(label: "탐험", value: dna.explorationScore)
                        DNAStatChip(label: "문화", value: dna.cultureScore)
                        DNAStatChip(label: "소셜", value: dna.socialScore)
                    }
                }

                Spacer()
            }

            // Traits
            if !dna.traits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(dna.traits, id: \.self) { trait in
                            HStack(spacing: 4) {
                                Text(trait.emoji)
                                Text(trait.koreanName)
                                    .font(WanderTypography.caption2)
                            }
                            .foregroundColor(WanderColors.textSecondary)
                            .padding(.horizontal, WanderSpacing.space2)
                            .padding(.vertical, 4)
                            .background(WanderColors.background)
                            .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Insights Preview
    private var insightsPreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("발견된 인사이트")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                if let summary = result.insightSummary {
                    Text("\(summary.totalCount)개 발견")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }

            // Top 3 Insights
            ForEach(result.insights.prefix(3), id: \.id) { insight in
                InsightCard(insight: insight)
            }

            // Show More
            if result.insights.count > 3 {
                Button(action: {}) {
                    HStack {
                        Text("더 보기")
                        Image(systemName: "chevron.right")
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.primary)
                }
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Story Preview Card
    private func storyPreviewCard(_ story: StoryWeavingService.TravelStory) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 스토리")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Text(story.mood.emoji)
                    Text(story.mood.koreanName)
                        .font(WanderTypography.caption1)
                }
                .foregroundColor(WanderColors.primary)
            }

            // Story Title
            Text(story.title)
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            // Tagline
            Text(story.tagline)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .italic()

            // Opening Preview
            Text(story.opening)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .lineLimit(3)

            // Keywords
            if !story.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: WanderSpacing.space2) {
                        ForEach(story.keywords, id: \.self) { keyword in
                            Text("#\(keyword)")
                                .font(WanderTypography.caption2)
                                .foregroundColor(WanderColors.primary)
                                .padding(.horizontal, WanderSpacing.space2)
                                .padding(.vertical, 4)
                                .background(WanderColors.primaryPale)
                                .cornerRadius(WanderSpacing.radiusSmall)
                        }
                    }
                }
            }

            // Read Full Story Button
            NavigationLink(destination: AIStoryFullView(story: story)) {
                HStack {
                    Text("전체 스토리 보기")
                    Image(systemName: "chevron.right")
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.primary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    // MARK: - Helper Functions
    private func gradeColor(for grade: MomentScoreService.MomentGrade) -> Color {
        switch grade {
        case .legendary: return Color(hex: "#FFD700") // Gold
        case .epic: return Color(hex: "#9B59B6") // Purple
        case .memorable: return WanderColors.primary
        case .pleasant: return WanderColors.success
        case .ordinary: return WanderColors.textSecondary
        case .casual: return WanderColors.textTertiary
        }
    }

    // MARK: - Timeline Section
    private var timelineSection: some View {
        let groupedByDate = groupPlacesByDate()
        let sortedDates = groupedByDate.keys.sorted()

        return VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("타임라인")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ForEach(Array(sortedDates.enumerated()), id: \.element) { dayIndex, date in
                // Day header
                DayHeader(dayNumber: dayIndex + 1, date: date)

                // Places for this day
                if let placesForDay = groupedByDate[date] {
                    let sortedPlaces = placesForDay.sorted { $0.startTime < $1.startTime }
                    ForEach(Array(sortedPlaces.enumerated()), id: \.element.id) { placeIndex, place in
                        TimelineCard(
                            place: place,
                            index: placeIndex,
                            isLast: placeIndex == sortedPlaces.count - 1
                        )
                    }
                }
            }
        }
    }

    /// 장소를 날짜별로 그룹화
    private func groupPlacesByDate() -> [Date: [PlaceCluster]] {
        let calendar = Calendar.current
        var grouped: [Date: [PlaceCluster]] = [:]

        for place in result.places {
            let dateOnly = calendar.startOfDay(for: place.startTime)
            if grouped[dateOnly] == nil {
                grouped[dateOnly] = []
            }
            grouped[dateOnly]?.append(place)
        }

        return grouped
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: WanderSpacing.space3) {
            // AI 다듬기 버튼
            aiEnhancementButton

            Button(action: saveRecord) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                    Text(isSaved ? "저장 완료" : "기록 저장하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(isSaved ? WanderColors.success : WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .disabled(isSaved)
        }
        .padding(.top, WanderSpacing.space4)
    }

    // MARK: - Save Record

    /// 공유 전 기록 자동 저장 (auto-dismiss 없음)
    /// - NOTE: saveRecord()과 동일한 저장 로직, 화면 전환만 생략
    private func ensureSaved() {
        guard !isSaved else { return }
        let record = TravelRecord(
            title: result.title,
            startDate: result.startDate,
            endDate: result.endDate
        )
        record.totalDistance = result.totalDistance
        record.placeCount = result.placeCount
        record.photoCount = selectedAssets.count // Use actual selected count

        // Collect photos that are in clusters
        var savedPhotoIds = Set<String>()

        // Group clusters by date
        let calendar = Calendar.current
        var clustersByDate: [Date: [PlaceCluster]] = [:]

        for cluster in result.places {
            let dateOnly = calendar.startOfDay(for: cluster.startTime)
            if clustersByDate[dateOnly] == nil {
                clustersByDate[dateOnly] = []
            }
            clustersByDate[dateOnly]?.append(cluster)
        }

        // Sort dates and create days
        let sortedDates = clustersByDate.keys.sorted()
        logger.info("💾 [ResultView] 날짜별 분류: \(sortedDates.count)일")

        for (dayIndex, date) in sortedDates.enumerated() {
            let dayNumber = dayIndex + 1
            let day = TravelDay(date: date, dayNumber: dayNumber)

            guard let clustersForDay = clustersByDate[date] else { continue }

            // Sort clusters by time within the day
            let sortedClusters = clustersForDay.sorted { $0.startTime < $1.startTime }

            for (placeIndex, cluster) in sortedClusters.enumerated() {
                let place = Place(
                    name: cluster.name,
                    address: cluster.address,
                    coordinate: cluster.coordinate,
                    startTime: cluster.startTime
                )
                place.activityLabel = cluster.activityType.displayName
                place.placeType = cluster.placeType ?? "other"
                place.order = placeIndex

                // Save photos to place
                for (photoIndex, asset) in cluster.photos.enumerated() {
                    let photo = PhotoItem(
                        assetIdentifier: asset.localIdentifier,
                        capturedAt: asset.creationDate,
                        latitude: asset.location?.coordinate.latitude,
                        longitude: asset.location?.coordinate.longitude
                    )
                    photo.order = photoIndex
                    place.photos.append(photo)
                    savedPhotoIds.insert(asset.localIdentifier)
                }

                day.places.append(place)
            }

            record.days.append(day)
            logger.info("💾 [ResultView] Day \(dayNumber): \(sortedClusters.count)개 장소")
        }

        // Find photos not in any cluster (no GPS or filtered out)
        let uncategorizedAssets = selectedAssets.filter { !savedPhotoIds.contains($0.localIdentifier) }

        if !uncategorizedAssets.isEmpty {
            // Add to the last day or create new day if no days exist
            let lastDay: TravelDay
            if let existingLastDay = record.days.last {
                lastDay = existingLastDay
            } else {
                lastDay = TravelDay(date: result.startDate, dayNumber: 1)
                record.days.append(lastDay)
            }

            // Create "미분류" place for uncategorized photos
            let uncategorizedPlace = Place(
                name: "미분류 사진",
                address: "",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                startTime: uncategorizedAssets.first?.creationDate ?? Date()
            )
            uncategorizedPlace.activityLabel = "기타"
            uncategorizedPlace.placeType = "other"
            uncategorizedPlace.order = lastDay.places.count

            for (photoIndex, asset) in uncategorizedAssets.enumerated() {
                let photo = PhotoItem(
                    assetIdentifier: asset.localIdentifier,
                    capturedAt: asset.creationDate,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                photo.order = photoIndex
                uncategorizedPlace.photos.append(photo)
            }

            lastDay.places.append(uncategorizedPlace)
            record.placeCount += 1
            logger.info("💾 [ResultView] 미분류 사진 \(uncategorizedAssets.count)장 추가")
        }

        // MARK: - Wander Intelligence 데이터 저장
        if let tripScore = result.tripScore {
            record.tripScore = tripScore
            logger.info("💾 [ResultView] 여행 점수 저장: \(tripScore.averageScore)점")
        }

        if let travelDNA = result.travelDNA {
            record.travelDNA = travelDNA
            logger.info("💾 [ResultView] 여행자 DNA 저장: \(travelDNA.primaryType.rawValue)")
        }

        if !result.insights.isEmpty {
            record.insights = result.insights
            logger.info("💾 [ResultView] 인사이트 저장: \(result.insights.count)개")
        }

        if let travelStory = result.travelStory {
            record.travelStory = travelStory
            logger.info("💾 [ResultView] 여행 스토리 저장: \(travelStory.title)")
        }

        if !result.allBadges.isEmpty {
            record.badges = result.allBadges
            logger.info("💾 [ResultView] 배지 저장: \(result.allBadges.count)개")
        }

        // 감성 키워드 저장 (Vision SDK 분석 결과)
        if !result.keywords.isEmpty {
            record.keywords = result.keywords
            logger.info("💾 [ResultView] 감성 키워드 저장: \(result.keywords.joined(separator: ", "))")
        }

        // 분석 레벨 저장
        if let smartResult = result.smartAnalysisResult {
            record.analysisLevel = smartResult.analysisLevel.displayName
        }

        // AI 다듬기 상태 저장
        if result.isAIEnhanced {
            record.isAIEnhanced = true
            record.aiEnhancedAt = result.aiEnhancedAt
            record.aiEnhancedProvider = result.aiEnhancedProvider
            record.aiEnhancedDNADescription = result.aiEnhancedDNADescription
            logger.info("💾 [ResultView] AI 다듬기 상태 저장 - provider: \(result.aiEnhancedProvider ?? "unknown")")
        }

        modelContext.insert(record)
        savedRecord = record

        logger.info("💾 [ResultView] 저장 완료 - 날짜: \(record.days.count)일, 장소: \(record.placeCount), 사진: \(selectedAssets.count), WI: \(record.hasWanderIntelligence)")

        withAnimation {
            isSaved = true
        }
    }

    /// 기록 저장 + 자동 닫기 (저장 버튼 액션)
    private func saveRecord() {
        ensureSaved()

        // 저장 후 1초 뒤 자동으로 닫기
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            logger.info("📊 [ResultView] 자동 닫기 - 저장된 기록으로 이동")
            if let record = savedRecord {
                onSaveComplete?(record)
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dismiss()
            }
        }
    }

    // MARK: - AI Enhancement Button

    @ViewBuilder
    private var aiEnhancementButton: some View {
        if hasConfiguredAIProvider {
            VStack(spacing: WanderSpacing.space2) {
                if result.isAIEnhanced {
                    // 완료 상태 배지
                    HStack(spacing: WanderSpacing.space2) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("AI로 다듬어짐")
                        if let provider = result.aiEnhancedProvider {
                            Text("· \(provider)")
                                .foregroundColor(WanderColors.textSecondary)
                        }
                    }
                    .font(WanderTypography.bodySmall)
                    .foregroundColor(WanderColors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WanderSpacing.space2)
                }

                Button(action: {
                    let providers = configuredProviders
                    if providers.count == 1, let singleProvider = providers.first {
                        performAIEnhancement(provider: singleProvider)
                    } else {
                        showAIEnhancement = true
                    }
                }) {
                    HStack(spacing: WanderSpacing.space2) {
                        if isEnhancing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isEnhancing ? "다듬는 중..." : (result.isAIEnhanced ? "다시 다듬기" : "AI로 다듬기"))
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(
                        LinearGradient(
                            colors: [WanderColors.primary, Color.purple.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(isEnhancing)
                .sheet(isPresented: $showAIEnhancement) {
                    AIEnhancementSheet(
                        isEnhancing: $isEnhancing,
                        enhancementError: $enhancementError,
                        onEnhance: { provider in
                            performAIEnhancement(provider: provider)
                        }
                    )
                    .presentationDetents([.medium])
                }
            }
        }
    }

    /// API 키 또는 OAuth가 설정된 프로바이더가 있는지 확인
    private var hasConfiguredAIProvider: Bool {
        GoogleOAuthService.shared.isAuthenticated ||
        AIProvider.allCases.contains { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
    }

    /// API 키가 설정된 프로바이더 목록 (OAuth 포함)
    /// - NOTE: Google OAuth 인증 시 .google을 목록에 포함
    private var configuredProviders: [AIProvider] {
        var providers = AIProvider.allCases.filter { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
        // OAuth로 인증된 Google도 포함 (API Key 미설정이지만 OAuth 가능)
        if GoogleOAuthService.shared.isAuthenticated && !providers.contains(.google) {
            providers.append(.google)
        }
        return providers
    }

    // MARK: - AI Enhancement Action

    private func performAIEnhancement(provider: AIProvider) {
        isEnhancing = true
        enhancementError = nil
        showAIEnhancement = false

        Task {
            do {
                let enhancementResult = try await AIEnhancementService.enhance(
                    result: result,
                    provider: provider,
                    selectedAssets: selectedAssets
                )

                await MainActor.run {
                    AIEnhancementService.apply(enhancementResult, to: &result)
                    result.aiEnhancedProvider = provider.displayName
                    isEnhancing = false
                    logger.info("✨ [ResultView] AI 다듬기 완료 - provider: \(provider.displayName)")
                }
            } catch {
                await MainActor.run {
                    isEnhancing = false
                    enhancementError = error.localizedDescription
                    showAIEnhancement = true
                    logger.error("✨ [ResultView] AI 다듬기 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - AI Enhancement Sheet

struct AIEnhancementSheet: View {
    @Binding var isEnhancing: Bool
    @Binding var enhancementError: String?
    let onEnhance: (AIProvider) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIProvider?

    /// API 키 또는 OAuth가 설정된 프로바이더 목록
    private var configuredProviders: [AIProvider] {
        var providers = AIProvider.allCases.filter { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
        if GoogleOAuthService.shared.isAuthenticated && !providers.contains(.google) {
            providers.append(.google)
        }
        return providers
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space6) {
                // 설명
                VStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(WanderColors.primary)

                    Text("AI로 다듬기")
                        .font(WanderTypography.title2)

                    Text("규칙 기반으로 생성된 텍스트를\n자연스럽고 감성적으로 다듬어줍니다.")
                        .font(WanderTypography.bodySmall)
                        .foregroundColor(WanderColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, WanderSpacing.space4)

                // 프로바이더 선택
                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    Text("AI 서비스 선택")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)

                    ForEach(configuredProviders) { provider in
                        Button {
                            selectedProvider = provider
                        } label: {
                            HStack {
                                Text(provider.displayName)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)

                                Spacer()

                                if selectedProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(WanderColors.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(WanderColors.textTertiary)
                                }
                            }
                            .padding(WanderSpacing.space3)
                            .background(selectedProvider == provider ? WanderColors.primaryPale : WanderColors.surface)
                            .cornerRadius(WanderSpacing.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                                    .stroke(selectedProvider == provider ? WanderColors.primary : WanderColors.border, lineWidth: 1)
                            )
                        }
                    }
                }

                // 에러 메시지
                if let error = enhancementError {
                    HStack(spacing: WanderSpacing.space1) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(WanderColors.error)
                        Text(error)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.error)
                    }
                    .padding(WanderSpacing.space3)
                    .background(WanderColors.errorBackground)
                    .cornerRadius(WanderSpacing.radiusMedium)
                }

                // 프라이버시 안내
                HStack(spacing: WanderSpacing.space1) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 12))
                    Text("장소명, 시간 정보만 전송됩니다. 사진은 전송되지 않습니다.")
                        .font(WanderTypography.caption2)
                }
                .foregroundColor(WanderColors.textTertiary)

                Spacer()

                // 다듬기 시작 버튼
                Button {
                    if let provider = selectedProvider {
                        onEnhance(provider)
                    }
                } label: {
                    Text("다듬기 시작")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(selectedProvider != nil ? WanderColors.primary : WanderColors.textTertiary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(selectedProvider == nil)
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.bottom, WanderSpacing.space4)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .onAppear {
            // 프로바이더가 1개면 자동 선택
            if configuredProviders.count == 1 {
                selectedProvider = configuredProviders.first
            }
        }
    }
}

// MARK: - Place Marker
struct PlaceMarker: View {
    let number: Int
    let activityType: ActivityType

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 4)

            Circle()
                .fill(WanderColors.primary)
                .frame(width: 28, height: 28)

            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: WanderSpacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(WanderColors.primary)

            Text(value)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(label)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}

// MARK: - Day Header
struct DayHeader: View {
    let dayNumber: Int
    let date: Date

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            Text(formatDate(date))
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.primary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space1)
                .background(WanderColors.primaryPale)
                .cornerRadius(WanderSpacing.radiusMedium)

            Spacer()
        }
        .padding(.top, dayNumber > 1 ? WanderSpacing.space4 : 0)
        .padding(.bottom, WanderSpacing.space2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Card
struct TimelineCard: View {
    let place: PlaceCluster
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space4) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Number circle - Vision 분석 결과 우선 사용
                ZStack {
                    Circle()
                        .fill(placeColor)
                        .frame(width: 36, height: 36)

                    Text(place.displayEmoji)
                        .font(.system(size: 16))
                }

                // Connector line
                if !isLast {
                    Rectangle()
                        .fill(WanderColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                // Time
                Text(formatTime(place.startTime))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                // Place name (betterName 우선 사용)
                Text(place.displayName)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                // Address
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                // Activity/Scene tag
                HStack(spacing: WanderSpacing.space1) {
                    Text(place.displayEmoji)
                    Text(activityLabel)
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space2)
                .padding(.vertical, WanderSpacing.space1)
                .background(placeColor)
                .cornerRadius(WanderSpacing.radiusSmall)

                // 주변 핫스팟 (스마트 분석 결과)
                if let hotspots = place.nearbyHotspots, !hotspots.isEmpty {
                    nearbyHotspotsView(hotspots)
                }

                // Photo count
                Text("사진 \(place.photos.count)장")
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(.bottom, isLast ? 0 : WanderSpacing.space4)

            Spacer()
        }
    }

    // 장면 분류 기반 색상 (있으면 사용, 없으면 기본 활동 색상)
    private var placeColor: Color {
        if let scene = place.sceneCategory {
            return scene.toActivityType.color
        }
        return place.activityType.color
    }

    // 활동 라벨 (장면 분류 우선)
    private var activityLabel: String {
        if let scene = place.sceneCategory, scene != .unknown {
            return scene.koreanName
        }
        return place.activityType.displayName
    }

    // 주변 핫스팟 뷰
    @ViewBuilder
    private func nearbyHotspotsView(_ hotspots: POIService.NearbyHotspots) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space1) {
            Text("주변")
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WanderSpacing.space2) {
                    // 카페
                    ForEach(hotspots.cafes.prefix(2)) { poi in
                        HotspotChip(emoji: "☕", name: poi.name)
                    }

                    // 맛집
                    ForEach(hotspots.restaurants.prefix(2)) { poi in
                        HotspotChip(emoji: "🍽️", name: poi.name)
                    }

                    // 명소
                    ForEach(hotspots.attractions.prefix(2)) { poi in
                        HotspotChip(emoji: "📸", name: poi.name)
                    }
                }
            }
        }
        .padding(.top, WanderSpacing.space1)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Hotspot Chip
struct HotspotChip: View {
    let emoji: String
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 10))
            Text(name)
                .font(WanderTypography.caption2)
                .lineLimit(1)
        }
        .foregroundColor(WanderColors.textSecondary)
        .padding(.horizontal, WanderSpacing.space2)
        .padding(.vertical, 4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusSmall)
    }
}

// MARK: - DNA Stat Chip
struct DNAStatChip: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WanderColors.textPrimary)
            Text(label)
                .font(WanderTypography.caption2)
                .foregroundColor(WanderColors.textTertiary)
        }
        .frame(width: 40)
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: InsightEngine.TravelInsight

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            // Emoji
            Text(insight.emoji)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(WanderColors.background)
                .cornerRadius(WanderSpacing.radiusMedium)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(WanderTypography.bodySmall)
                        .foregroundColor(WanderColors.textPrimary)

                    Spacer()

                    // Importance indicator
                    if insight.importance >= .highlight {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                            .foregroundColor(WanderColors.warning)
                    }
                }

                Text(insight.description)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(WanderSpacing.space3)
        .background(WanderColors.background)
        .cornerRadius(WanderSpacing.radiusMedium)
    }
}

// MARK: - AI Story Full View
struct AIStoryFullView: View {
    let story: StoryWeavingService.TravelStory
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WanderSpacing.space5) {
                // Header
                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    HStack {
                        Text(story.mood.emoji)
                        Text(story.mood.koreanName)
                            .font(WanderTypography.caption1)
                    }
                    .foregroundColor(WanderColors.primary)

                    Text(story.title)
                        .font(WanderTypography.title1)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(story.tagline)
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)
                        .italic()
                }

                Divider()

                // Opening
                Text(story.opening)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)
                    .lineSpacing(6)

                // Chapters
                ForEach(story.chapters.indices, id: \.self) { index in
                    chapterView(story.chapters[index], number: index + 1)
                }

                // Climax
                if !story.climax.isEmpty {
                    VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                        Text("✨ 하이라이트")
                            .font(WanderTypography.headline)
                            .foregroundColor(WanderColors.primary)

                        Text(story.climax)
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textPrimary)
                            .lineSpacing(6)
                    }
                    .padding(WanderSpacing.space4)
                    .background(WanderColors.primaryPale)
                    .cornerRadius(WanderSpacing.radiusMedium)
                }

                // Closing
                Text(story.closing)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)
                    .lineSpacing(6)

                // Keywords
                if !story.keywords.isEmpty {
                    Divider()

                    FlowLayout(spacing: WanderSpacing.space2) {
                        ForEach(story.keywords, id: \.self) { keyword in
                            Text("#\(keyword)")
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.primary)
                                .padding(.horizontal, WanderSpacing.space3)
                                .padding(.vertical, WanderSpacing.space2)
                                .background(WanderColors.primaryPale)
                                .cornerRadius(WanderSpacing.radiusMedium)
                        }
                    }
                }
            }
            .padding(WanderSpacing.screenMargin)
        }
        .background(WanderColors.background)
        .navigationTitle("여행 스토리")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chapterView(_ chapter: StoryWeavingService.StoryChapter, number: Int) -> some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("Chapter \(number)")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                Spacer()

                Text(chapter.placeName)
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }

            Text(chapter.title)
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            Text(chapter.content)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .lineSpacing(4)
        }
        .padding(.vertical, WanderSpacing.space2)
    }
}

// MARK: - Flow Layout (for Keywords)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

// MARK: - Share Format
enum ShareFormat: String, CaseIterable, Identifiable {
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

// MARK: - Share Sheet View (Format Selection → Preview → Share)
struct ShareSheetView: View {
    let result: AnalysisResult
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ShareFormat = .image
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
                    ForEach(ShareFormat.allCases) { format in
                        ShareFormatCard(
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
                SharePreviewView(result: result, format: selectedFormat, onDismissAll: { dismiss() })
            }
        }
    }
}

// MARK: - Share Format Card
struct ShareFormatCard: View {
    let format: ShareFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WanderSpacing.space4) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? WanderColors.primary : WanderColors.surface)
                        .frame(width: 48, height: 48)

                    Image(systemName: format.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.title)
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Text(format.description)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Spacer()

                // Checkmark
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

// MARK: - Share Preview View
struct SharePreviewView: View {
    let result: AnalysisResult
    let format: ShareFormat
    let onDismissAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var previewImage: UIImage?
    @State private var previewText: String = ""
    @State private var isSharing = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview Content
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
                // Share Button
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

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
                .frame(height: 100)

            ProgressView()
                .scaleEffect(1.5)

            Text("미리보기 생성 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
                .frame(height: 100)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Text Preview
    private var textPreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Format badge
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

            // Text content
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

    // MARK: - Image Preview
    private var imagePreview: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            // Format badge
            HStack {
                Image(systemName: "photo")
                Text("이미지 미리보기 (1080×1920)")
            }
            .font(WanderTypography.caption1)
            .foregroundColor(WanderColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WanderColors.primaryPale)
            .cornerRadius(WanderSpacing.radiusMedium)

            // Image content
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(WanderSpacing.radiusLarge)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        }
    }

    // MARK: - Generate Preview
    private func generatePreview() {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            switch format {
            case .text:
                let text = ExportService.shared.exportAsText(result: result)
                await MainActor.run {
                    previewText = text
                    isLoading = false
                }

            case .image:
                let image = await ExportService.shared.exportAsImage(result: result)
                await MainActor.run {
                    previewImage = image
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Perform Share
    private func performShare() {
        isSharing = true
        logger.info("📤 [SharePreview] 공유 시작 - 형식: \(format.title)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            var items: [Any] = []

            switch format {
            case .text:
                items = [previewText]
            case .image:
                if let image = previewImage {
                    // JPEG 압축으로 메모리 사용량 감소 (카카오톡 등 외부 앱 호환성 향상)
                    if let jpegData = image.jpegData(compressionQuality: 0.85),
                       let compressedImage = UIImage(data: jpegData) {
                        items = [compressedImage]
                    } else {
                        items = [image]
                    }
                }
            }

            guard !items.isEmpty else {
                isSharing = false
                return
            }

            showActivitySheet(with: items)
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
                logger.info("📤 [SharePreview] 공유 완료")
                onDismissAll()
            }
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.maxY - 100, width: 0, height: 0)
            popover.permittedArrowDirections = .down
        }

        topVC.present(activityVC, animated: true) {
            logger.info("📤 [SharePreview] Activity sheet 표시됨")
        }
    }
}

// MARK: - Activity View Controller (UIKit Wrapper)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ResultView(
        result: AnalysisResult(),
        selectedAssets: []
    )
}
