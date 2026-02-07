import Foundation
import Photos
import CoreLocation
import SwiftData
import SwiftyH3
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AnalysisEngine")

@MainActor
@Observable
class AnalysisEngine {
    // MARK: - Properties
    var progress: Double = 0
    var currentStep: String = ""
    var isAnalyzing: Bool = false
    var error: AnalysisError?

    /// 스마트 분석 진행 상황 (UI 표시용)
    var smartAnalysisProgress: SmartAnalysisCoordinator.AnalysisProgress?

    /// 현재 분석 레벨
    var currentAnalysisLevel: SmartAnalysisCoordinator.AnalysisLevel = .basic

    private let geocodingService = GeocodingService()
    private let clusteringService = ClusteringService()
    private let activityService = ActivityInferenceService()
    private let smartCoordinator = SmartAnalysisCoordinator()
    private let visionService = VisionAnalysisService()
    private let contextService = ContextClassificationService()

    /// 사용자 장소 목록 (분석 전 설정)
    var userPlaces: [UserPlace] = []

    /// 학습된 장소 목록 (분석 전 설정)
    var learnedPlaces: [LearnedPlace] = []

    /// 스마트 분석 활성화 여부 (기본: true)
    var enableSmartAnalysis: Bool = true

    /// Context Classification 활성화 여부 (기본: true)
    var enableContextClassification: Bool = true

    /// SwiftData ModelContext (학습 장소 업데이트용, 분석 전 설정)
    var modelContext: ModelContext?

    // MARK: - Analyze
    func analyze(assets: [PHAsset]) async throws -> AnalysisResult {
        logger.info("🔬 [Engine] 분석 시작 - 총 \(assets.count)장")
        isAnalyzing = true
        progress = 0
        error = nil
        currentAnalysisLevel = enableSmartAnalysis ? SmartAnalysisCoordinator.availableLevel : .basic

        defer {
            isAnalyzing = false
            logger.info("🔬 [Engine] 분석 종료 (defer)")
        }

        // ===== Phase 1: 기본 분석 =====

        // Step 1: Extract metadata
        currentStep = "📸 사진 메타데이터 읽는 중..."
        progress = 0.05
        logger.info("🔬 [Step 1] 메타데이터 추출 시작")

        let photosWithMetadata = extractMetadata(from: assets)
        logger.info("🔬 [Step 1] 메타데이터 추출 완료: \(photosWithMetadata.count)장")
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Step 2: Filter photos with GPS
        currentStep = "📍 위치 정보 추출 중..."
        progress = 0.10
        logger.info("🔬 [Step 2] GPS 필터링 시작")

        let gpsPhotos = photosWithMetadata.filter { $0.hasGPS }
        let sortedPhotos = gpsPhotos.sorted { ($0.capturedAt ?? Date()) < ($1.capturedAt ?? Date()) }
        logger.info("🔬 [Step 2] GPS 있는 사진: \(gpsPhotos.count)장 / 전체 \(photosWithMetadata.count)장")

        if sortedPhotos.isEmpty {
            logger.error("🔬 [Step 2] ❌ GPS 데이터 없음!")
            throw AnalysisError.noGPSData
        }

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Step 3: Clustering
        currentStep = "📊 동선 분석 중..."
        progress = 0.15
        logger.info("🔬 [Step 3] 클러스터링 시작")

        let clusters = clusteringService.cluster(photos: sortedPhotos)
        logger.info("🔬 [Step 3] 클러스터링 완료: \(clusters.count)개 장소")
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Step 4: Reverse geocoding
        currentStep = "🗺️ 주소 정보 변환 중..."
        progress = 0.20
        logger.info("🔬 [Step 4] Reverse geocoding 시작")

        // Geocoding 결과 저장 (스마트 분석 및 Context Classification에서 활용)
        var geocodingResults: [UUID: GeocodingService.GeocodingResult] = [:]

        for (index, cluster) in clusters.enumerated() {
            logger.info("🔬 [Step 4] 장소 \(index + 1)/\(clusters.count) geocoding...")
            do {
                let address = try await geocodingService.reverseGeocode(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude
                )
                cluster.name = address.name
                cluster.address = address.fullAddress
                cluster.placeType = address.placeType

                // v3.1: 행정구역 정보 저장 (Context Classification용)
                cluster.administrativeArea = address.administrativeArea
                cluster.locality = address.locality
                cluster.subLocality = address.subLocality

                geocodingResults[cluster.id] = address
                logger.info("🔬 [Step 4] → \(address.name) (\(address.administrativeArea ?? "-") \(address.locality ?? "-"))")
            } catch {
                logger.warning("🔬 [Step 4] geocoding 실패: \(error.localizedDescription)")
                // 좌표 기반 기본 이름 생성
                cluster.name = generateFallbackPlaceName(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude,
                    index: index
                )
                cluster.address = String(format: "%.4f, %.4f", cluster.latitude, cluster.longitude)
                logger.info("🔬 [Step 4] → 대체 이름 사용: \(cluster.name)")
            }

            progress = 0.20 + (0.10 * Double(index + 1) / Double(clusters.count))
        }

        // Step 4.5: User place matching
        if !userPlaces.isEmpty {
            currentStep = "🏠 등록된 장소 매칭 중..."
            progress = 0.32
            let userPlaceCount = self.userPlaces.count
            logger.info("🔬 [Step 4.5] 사용자 장소 매칭 시작 - 등록 장소: \(userPlaceCount)개")

            for cluster in clusters {
                if let matchedPlace = findMatchingUserPlace(for: cluster) {
                    let originalName = cluster.name
                    cluster.name = matchedPlace.name
                    cluster.userPlaceMatched = true
                    logger.info("🔬 [Step 4.5] ✓ 매칭: \(originalName) → \(matchedPlace.name)")
                }
            }
        }

        // Step 5: Activity inference (기본)
        currentStep = "✨ 활동 유형 분석 중..."
        progress = 0.35
        logger.info("🔬 [Step 5] 활동 추론 시작")

        for cluster in clusters {
            if cluster.userPlaceMatched {
                cluster.activityType = inferActivityForUserPlace(cluster.name, time: cluster.startTime)
            } else {
                cluster.activityType = activityService.infer(
                    placeType: cluster.placeType,
                    time: cluster.startTime
                )
            }
            logger.info("🔬 [Step 5] \(cluster.name): \(cluster.activityType.displayName)")
        }

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Step 6: Build basic result
        currentStep = "📝 기본 결과 정리 중..."
        progress = 0.40
        logger.info("🔬 [Step 6] 기본 결과 빌드")

        var result = buildResult(
            assets: assets,
            gpsPhotos: sortedPhotos,
            clusters: clusters
        )

        // Step 6.5: Context Classification (v3.1)
        if enableContextClassification {
            currentStep = "🏠 일상/여행 판별 중..."
            progress = 0.42
            logger.info("🔬 [Step 6.5] Context Classification 시작")

            let classificationResult = classifyContext(clusters: clusters, geocodingResults: geocodingResults)
            result.context = classificationResult.context
            result.contextConfidence = classificationResult.confidence
            result.contextReasoning = classificationResult.reasoning
            result.mixedContextInfo = classificationResult.mixedInfo

            logger.info("🔬 [Step 6.5] Context: \(classificationResult.context.emoji) \(classificationResult.context.displayName) (신뢰도: \(Int(classificationResult.confidence * 100))%)")

            // Context에 따른 제목 조정
            result.title = adjustTitleForContext(
                baseTitle: result.title,
                context: classificationResult.context,
                clusters: clusters
            )

            // Step 6.6: 학습 장소 업데이트 (v3.2: H3 res9 기반)
            if let modelContext = modelContext {
                updateLearnedPlaces(clusters: clusters, modelContext: modelContext)
            }
        }

        // ===== Phase 2: 스마트 분석 (iOS 17+) =====

        if enableSmartAnalysis && currentAnalysisLevel >= .smart {
            logger.info("🔬 [Smart] 스마트 분석 시작 - 레벨: \(self.currentAnalysisLevel.displayName)")

            currentStep = "🤖 스마트 분석 시작..."
            progress = 0.45

            do {
                let smartResult = try await smartCoordinator.runSmartAnalysis(
                    clusters: clusters,
                    basicResult: result,
                    level: currentAnalysisLevel,
                    context: result.context
                )

                // 스마트 분석 결과 병합
                smartCoordinator.mergeResults(smartResult: smartResult, into: &result)

                // 추가 정보 저장 (나중에 UI에서 활용)
                result.smartAnalysisResult = smartResult
                
                // [추가] Vision 분석 결과 기반으로 활동 타입 재추론 (보정)
                logger.info("🔬 [Smart] Vision 결과로 활동 타입 보정 시작")
                for cluster in clusters {
                    if let scene = cluster.sceneCategory {
                        let newActivity = activityService.infer(
                            placeType: cluster.placeType,
                            time: cluster.startTime,
                            sceneCategory: scene
                        )
                        if newActivity != cluster.activityType {
                            logger.info("🔬 [Smart] 활동 타입 변경: \(cluster.name) (\(cluster.activityType.rawValue) -> \(newActivity.rawValue))")
                            cluster.activityType = newActivity
                        }
                    }
                }

                logger.info("🔬 [Smart] 스마트 분석 완료!")
                logger.info("🔬 [Smart] - 스마트 제목: \(smartResult.smartTitle)")
                logger.info("🔬 [Smart] - Vision 분석: \(smartResult.visionClassificationCount)장")
                logger.info("🔬 [Smart] - POI 검색: \(smartResult.poiSearchCount)개")

            } catch {
                logger.warning("🔬 [Smart] 스마트 분석 실패 (기본 결과 사용): \(error.localizedDescription)")
                // 스마트 분석 실패해도 기본 결과는 유지
            }
        }

        // ===== Phase 3: 감성 키워드 추출 (Vision SDK) =====

        currentStep = "✨ 감성 키워드 분석 중..."
        progress = 0.90
        logger.info("🔬 [Keywords] 감성 키워드 추출 시작")

        let keywords = await visionService.extractKeywords(from: assets, maxKeywords: 5, context: result.context)
        result.keywords = keywords
        logger.info("🔬 [Keywords] 키워드 추출 완료: \(keywords.joined(separator: ", "))")

        // 최종 완료
        progress = 1.0
        currentStep = "완료!"
        logger.info("🔬 ✅ 분석 완료 - 제목: \(result.title), 장소: \(result.places.count)개")

        return result
    }

    // MARK: - Extract Metadata
    private func extractMetadata(from assets: [PHAsset]) -> [PhotoMetadata] {
        var noDateCount = 0
        var noGPSCount = 0

        let metadata = assets.enumerated().map { index, asset -> PhotoMetadata in
            let capturedAt = asset.creationDate
            let location = asset.location

            // 디버깅: 메타데이터 누락 추적
            if capturedAt == nil {
                noDateCount += 1
                logger.warning("🔬 [Metadata] 사진[\(index)] 날짜 정보 없음 - \(asset.localIdentifier)")
            }
            if location == nil {
                noGPSCount += 1
            }

            return PhotoMetadata(
                asset: asset,
                assetId: asset.localIdentifier,
                capturedAt: capturedAt,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude
            )
        }

        // 메타데이터 누락 요약
        if noDateCount > 0 {
            logger.warning("🔬 [Metadata] ⚠️ 날짜 없는 사진: \(noDateCount)장 (현재 시간으로 대체됨)")
        }
        logger.info("🔬 [Metadata] GPS 없는 사진: \(noGPSCount)장 / 전체 \(assets.count)장")

        return metadata
    }

    // MARK: - Build Result
    private func buildResult(
        assets: [PHAsset],
        gpsPhotos: [PhotoMetadata],
        clusters: [PlaceCluster]
    ) -> AnalysisResult {
        var result = AnalysisResult()

        // Date range
        if let firstDate = gpsPhotos.first?.capturedAt,
           let lastDate = gpsPhotos.last?.capturedAt {
            result.startDate = firstDate
            result.endDate = lastDate
        }

        // Title
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"

        if let firstPlace = clusters.first?.name {
            result.title = "\(firstPlace) 여행"
        } else {
            result.title = "\(formatter.string(from: result.startDate)) 여행"
        }

        // Stats
        result.photoCount = assets.count
        result.places = clusters
        result.totalDistance = calculateTotalDistance(clusters: clusters)
        
        // Layout Type 결정
        if assets.count < 5 {
            result.layoutType = "magazine"
        } else if clusters.count > 5 {
            result.layoutType = "grid"
        } else {
            result.layoutType = "timeline"
        }

        // Theme 결정
        result.theme = determineBasicTheme(clusters: clusters)

        return result
    }

    // MARK: - Calculate Distance
    private func calculateTotalDistance(clusters: [PlaceCluster]) -> Double {
        guard clusters.count > 1 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(clusters.count - 1) {
            let from = CLLocation(latitude: clusters[i].latitude, longitude: clusters[i].longitude)
            let to = CLLocation(latitude: clusters[i + 1].latitude, longitude: clusters[i + 1].longitude)
            totalDistance += from.distance(from: to)
        }

        return totalDistance / 1000 // Convert to km
    }

    // MARK: - Fallback Place Name
    /// Geocoding 실패 시 대체 장소 이름 생성
    private func generateFallbackPlaceName(latitude: Double, longitude: Double, index: Int) -> String {
        // 시간대 기반 이름 생성
        let formatter = DateFormatter()
        formatter.dateFormat = "HH시"
        let timeStr = formatter.string(from: Date())

        // 순서 기반 이름
        let orderNames = ["첫 번째", "두 번째", "세 번째", "네 번째", "다섯 번째"]
        let orderName = index < orderNames.count ? orderNames[index] : "\(index + 1)번째"

        return "\(orderName) 장소"
    }

    // MARK: - User Place Matching
    /// 클러스터 좌표와 매칭되는 사용자 장소 찾기 (반경 100m 이내)
    private func findMatchingUserPlace(for cluster: PlaceCluster) -> UserPlace? {
        let clusterCoordinate = CLLocationCoordinate2D(
            latitude: cluster.latitude,
            longitude: cluster.longitude
        )

        for userPlace in userPlaces {
            // 좌표가 설정되지 않은 장소는 건너뛰기
            guard userPlace.latitude != 0 && userPlace.longitude != 0 else { continue }

            let distance = userPlace.distance(from: clusterCoordinate)
            if distance <= UserPlace.matchingRadius {
                return userPlace
            }
        }

        return nil
    }

    /// 사용자 장소에 맞는 활동 타입 추론
    private func inferActivityForUserPlace(_ placeName: String, time: Date) -> ActivityType {
        let lowerName = placeName.lowercased()
        let hour = Calendar.current.component(.hour, from: time)

        // 집 - 시간대별 활동 추론
        if lowerName.contains("집") || lowerName.contains("home") || lowerName.contains("🏠") {
            if hour >= 6 && hour < 9 {
                return .other // 아침 준비
            } else if hour >= 22 || hour < 6 {
                return .accommodation // 휴식/수면
            } else {
                return .other // 일반 시간
            }
        }

        // 회사/학교 - 근무/학업
        if lowerName.contains("회사") || lowerName.contains("학교") || lowerName.contains("사무실") ||
           lowerName.contains("office") || lowerName.contains("work") || lowerName.contains("school") ||
           lowerName.contains("🏢") || lowerName.contains("🏫") {
            return .other // 근무/학업
        }

        // 병원
        if lowerName.contains("병원") || lowerName.contains("hospital") || lowerName.contains("🏥") {
            return .other
        }

        // 카페
        if lowerName.contains("카페") || lowerName.contains("커피") || lowerName.contains("cafe") ||
           lowerName.contains("coffee") || lowerName.contains("☕") {
            return .cafe
        }

        // 식당/맛집
        if lowerName.contains("식당") || lowerName.contains("맛집") || lowerName.contains("레스토랑") ||
           lowerName.contains("restaurant") || lowerName.contains("🍽️") {
            return .restaurant
        }

        // 헬스장/체육관
        if lowerName.contains("헬스") || lowerName.contains("체육관") || lowerName.contains("gym") ||
           lowerName.contains("fitness") || lowerName.contains("🏟️") {
            return .tourist
        }

        // 공원/자연
        if lowerName.contains("공원") || lowerName.contains("산") || lowerName.contains("park") ||
           lowerName.contains("🌳") || lowerName.contains("🏔️") || lowerName.contains("🏖️") {
            return .nature
        }

        // 마트/쇼핑
        if lowerName.contains("마트") || lowerName.contains("쇼핑") || lowerName.contains("백화점") ||
           lowerName.contains("mart") || lowerName.contains("shopping") ||
           lowerName.contains("🏪") || lowerName.contains("🏬") {
            return .shopping
        }

        return .other
    }

    /// 기본 여행 테마 결정 (활동 유형 빈도 기반)
    private func determineBasicTheme(clusters: [PlaceCluster]) -> String? {
        var counts: [ActivityType: Int] = [:]
        for cluster in clusters {
            counts[cluster.activityType, default: 0] += 1
        }

        let sorted = counts.sorted { $0.value > $1.value }
        guard let top = sorted.first else { return nil }

        // 전체 장소의 40% 이상을 차지하는 활동이 있으면 테마로 선정
        if Double(top.value) / Double(clusters.count) >= 0.4 {
            switch top.key {
            case .cafe: return "카페 투어"
            case .restaurant: return "식도락 여행"
            case .beach: return "바다 여행"
            case .mountain, .nature: return "힐링 여행"
            case .culture, .tourist: return "문화 탐방"
            case .shopping: return "쇼핑 여행"
            case .nightlife: return "밤거리 탐방"
            default: return nil
            }
        }
        return nil
    }

    // MARK: - Context Classification (v3.2: H3 기반)

    /// 클러스터들을 분석하여 Context 분류 (H3 셀 비교, 오프라인)
    private func classifyContext(
        clusters: [PlaceCluster],
        geocodingResults: [UUID: GeocodingService.GeocodingResult]
    ) -> ContextClassificationResult {
        // ClusterH3Info 생성 (SwiftyH3로 좌표 → H3 셀 인덱스 변환)
        let clusterInfos: [ClusterH3Info] = clusters.map { cluster in
            let dateRange = cluster.startTime...(cluster.endTime ?? cluster.startTime)
            return ClusterH3Info.from(
                clusterId: cluster.id,
                coordinate: cluster.coordinate,
                photoCount: cluster.photos.count,
                dateRange: dateRange
            )
        }

        return contextService.classify(
            clusterInfos: clusterInfos,
            userPlaces: userPlaces,
            learnedPlaces: learnedPlaces
        )
    }

    // MARK: - Learned Place Update (v3.2: H3 기반)

    /// 분석된 클러스터들로 LearnedPlace 방문 기록 업데이트
    /// H3 res9 셀 ID로 장소를 식별하고 HoWDe 비율 재계산
    private func updateLearnedPlaces(
        clusters: [PlaceCluster],
        modelContext: ModelContext
    ) {
        logger.info("📊 [LearnedPlace] 학습 장소 업데이트 시작 - 클러스터: \(clusters.count)개")

        for cluster in clusters {
            let coord = CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude)
            guard let h3Cell = try? coord.h3LatLng.cell(at: .res9).description else {
                logger.warning("📊 [LearnedPlace] H3 인덱스 계산 실패: (\(cluster.latitude), \(cluster.longitude))")
                continue
            }

            // 기존 LearnedPlace 찾기 (H3 res9 매칭)
            let existingPlace = learnedPlaces.first { $0.matches(h3CellRes9: h3Cell) }

            if let place = existingPlace {
                // 기존 장소: 방문 기록 추가
                place.recordVisit(at: cluster.startTime)
                logger.info("📊 [LearnedPlace] 기존 장소 업데이트: \(place.locationSummary) (방문 \(place.totalVisitDays)일)")
            } else {
                // 새 장소: LearnedPlace 생성
                let newPlace = LearnedPlace(coordinate: coord)
                newPlace.recordVisit(at: cluster.startTime)
                modelContext.insert(newPlace)
                learnedPlaces.append(newPlace)
                logger.info("📊 [LearnedPlace] 새 장소 학습: H3=\(h3Cell.prefix(12))...")
            }
        }

        try? modelContext.save()
        let totalCount = self.learnedPlaces.count
        logger.info("📊 [LearnedPlace] 학습 장소 업데이트 완료 - 총 \(totalCount)개")
    }

    /// Context에 따른 제목 조정
    private func adjustTitleForContext(
        baseTitle: String,
        context: TravelContext,
        clusters: [PlaceCluster]
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        switch context {
        case .daily:
            // 일상: "1월 17일 금요일"
            formatter.dateFormat = "M월 d일 EEEE"
            if let firstDate = clusters.first?.startTime {
                return formatter.string(from: firstDate)
            }
            return baseTitle

        case .outing:
            // 외출: 장소명 중심 "성수동 맛집 탐방"
            if let mainLocality = clusters.first?.locality ?? clusters.first?.subLocality {
                // 활동 유형에 따른 접미사
                let suffix = determineOutingSuffix(clusters: clusters)
                return "\(mainLocality) \(suffix)"
            }
            return baseTitle

        case .travel:
            // 여행: 기본 제목 유지 or "제주도 3박4일"
            if let mainArea = clusters.first?.administrativeArea {
                let dayCount = calculateTripDayCount(clusters: clusters)
                if dayCount > 1 {
                    return "\(mainArea) \(dayCount - 1)박\(dayCount)일"
                }
                return "\(mainArea) 당일치기"
            }
            return baseTitle

        case .mixed:
            // 혼합: 기본 제목 유지
            return baseTitle
        }
    }

    /// 외출 제목 접미사 결정
    private func determineOutingSuffix(clusters: [PlaceCluster]) -> String {
        var activityCounts: [ActivityType: Int] = [:]
        for cluster in clusters {
            activityCounts[cluster.activityType, default: 0] += 1
        }

        guard let dominant = activityCounts.max(by: { $0.value < $1.value }) else {
            return "나들이"
        }

        switch dominant.key {
        case .cafe: return "카페 투어"
        case .restaurant: return "맛집 탐방"
        case .shopping: return "쇼핑"
        case .culture, .tourist: return "문화 나들이"
        case .nature, .mountain: return "산책"
        default: return "나들이"
        }
    }

    /// 여행 일수 계산
    private func calculateTripDayCount(clusters: [PlaceCluster]) -> Int {
        guard let first = clusters.first?.startTime,
              let last = clusters.last?.endTime ?? clusters.last?.startTime else {
            return 1
        }

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: last)).day ?? 0
        return max(1, days + 1)
    }
}

// MARK: - Photo Metadata
struct PhotoMetadata {
    let asset: PHAsset
    let assetId: String
    let capturedAt: Date?
    let latitude: Double?
    let longitude: Double?

    var hasGPS: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Analysis Error
enum AnalysisError: LocalizedError {
    case noGPSData
    case geocodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .noGPSData:
            return "선택한 사진에 위치 정보가 없습니다"
        case .geocodingFailed:
            return "주소 변환에 실패했습니다"
        case .unknown:
            return "알 수 없는 오류가 발생했습니다"
        }
    }
}
