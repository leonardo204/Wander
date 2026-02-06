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
    @State private var pendingP2PShareResult: P2PShareResult?
    @State private var p2pShareResultWrapper: P2PShareResultWrapper?

    // AI 다듬기
    @State private var showAIEnhancement = false
    @State private var isEnhancing = false
    @State private var enhancementError: String?
    
    // UI State
    @State private var isIntelligenceExpanded = false

    init(result: AnalysisResult, selectedAssets: [PHAsset], onSaveComplete: ((TravelRecord) -> Void)? = nil, onDismiss: (() -> Void)? = nil) {
        self._result = State(initialValue: result)
        self.selectedAssets = selectedAssets
        self.onSaveComplete = onSaveComplete
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // 1. Map & Stats (Fact)
                    ResultMapSection(places: result.places)
                    ResultStatsSection(result: result)

                    // 2. Layout Based Content
                    layoutContentView

                    // 3. Wander Intelligence (Optional/Insight)
                    // 사용자 피드백: "필요한 경우만 나타나고" -> 접기/펼치기 UI 적용
                    if result.hasWanderIntelligence || !result.insights.isEmpty {
                        intelligenceDisclosureGroup
                    }

                    // 4. Action Buttons
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
                        onDismiss?()
                    }
                }

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
            // ... Sheets (Share, P2P, AI Enhancement) ...
            .sheet(isPresented: $showShareSheet) {
                if let record = savedRecord {
                    ShareFlowView(record: record)
                }
            }
            .sheet(isPresented: $showP2PShareOptions, onDismiss: {
                if let result = pendingP2PShareResult {
                    pendingP2PShareResult = nil
                    p2pShareResultWrapper = P2PShareResultWrapper(result: result)
                }
            }) {
                if let record = savedRecord {
                    P2PShareOptionsView(record: record) { result in
                        pendingP2PShareResult = result
                        showP2PShareOptions = false
                    }
                }
            }
            .sheet(item: $p2pShareResultWrapper) { wrapper in
                P2PShareCompleteView(shareResult: wrapper.result) {
                    p2pShareResultWrapper = nil
                }
            }
        }
    }

    // MARK: - Layout Content
    @ViewBuilder
    private var layoutContentView: some View {
        switch result.layoutType {
        case "magazine":
            MagazineLayoutView(places: result.places)
        case "grid":
            GridLayoutView(places: result.places)
        default: // timeline
            TimelineLayoutView(places: result.places)
        }
    }

    // MARK: - Intelligence Section (Expandable)
    private var intelligenceDisclosureGroup: some View {
        DisclosureGroup(isExpanded: $isIntelligenceExpanded) {
            VStack(spacing: WanderSpacing.space5) {
                Divider()
                WanderIntelligenceSection(result: result)
            }
            .padding(.top, WanderSpacing.space2)
        } label: {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(WanderColors.primary)
                Text("여행 분석 더보기")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
                Spacer()
                if !isIntelligenceExpanded {
                    Text("DNA, 인사이트 등")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                }
            }
            .padding(.vertical, WanderSpacing.space2)
        }
        .accentColor(WanderColors.primary)
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
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
    private func ensureSaved() {
        guard !isSaved else { return }
        
        let record = TravelRecord(
            title: result.title,
            startDate: result.startDate,
            endDate: result.endDate
        )
        record.totalDistance = result.totalDistance
        record.placeCount = result.placeCount
        record.photoCount = selectedAssets.count
        
        // Layout & Theme 저장
        record.layoutType = result.layoutType
        record.theme = result.theme

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
        }

        // Find photos not in any cluster (no GPS or filtered out)
        let uncategorizedAssets = selectedAssets.filter { !savedPhotoIds.contains($0.localIdentifier) }

        if !uncategorizedAssets.isEmpty {
            let lastDay: TravelDay
            if let existingLastDay = record.days.last {
                lastDay = existingLastDay
            } else {
                lastDay = TravelDay(date: result.startDate, dayNumber: 1)
                record.days.append(lastDay)
            }

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
        }

        // MARK: - Wander Intelligence 데이터 저장
        if let tripScore = result.tripScore {
            record.tripScore = tripScore
        }

        if let travelDNA = result.travelDNA {
            record.travelDNA = travelDNA
        }

        if !result.insights.isEmpty {
            record.insights = result.insights
        }

        if let travelStory = result.travelStory {
            record.travelStory = travelStory
        }

        if !result.allBadges.isEmpty {
            record.badges = result.allBadges
        }

        if !result.keywords.isEmpty {
            record.keywords = result.keywords
        }

        if let smartResult = result.smartAnalysisResult {
            record.analysisLevel = smartResult.analysisLevel.displayName
        }

        if result.isAIEnhanced {
            record.isAIEnhanced = true
            record.aiEnhancedAt = result.aiEnhancedAt
            record.aiEnhancedProvider = result.aiEnhancedProvider
            record.aiEnhancedDNADescription = result.aiEnhancedDNADescription
        }

        modelContext.insert(record)
        savedRecord = record

        withAnimation {
            isSaved = true
        }
    }

    /// 기록 저장 + 자동 닫기 (저장 버튼 액션)
    private func saveRecord() {
        ensureSaved()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

    // MARK: - AI Enhancement Button & Logic
    // (이전과 동일한 로직, 코드 길이상 생략된 부분은 기존 코드 유지)
    
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

    private var hasConfiguredAIProvider: Bool {
        GoogleOAuthService.shared.isAuthenticated ||
        AIProvider.allCases.contains { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
    }

    private var configuredProviders: [AIProvider] {
        var providers = AIProvider.allCases.filter { provider in
            (try? KeychainManager.shared.getAPIKey(for: provider.keychainType)) != nil
        }
        if GoogleOAuthService.shared.isAuthenticated && !providers.contains(.google) {
            providers.append(.google)
        }
        return providers
    }

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