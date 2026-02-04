import Foundation
import Photos
import CoreLocation
import SwiftData
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

    /// 사용자 장소 목록 (분석 전 설정)
    var userPlaces: [UserPlace] = []

    /// 스마트 분석 활성화 여부 (기본: true)
    var enableSmartAnalysis: Bool = true

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

        // Geocoding 결과 저장 (스마트 분석에서 활용)
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
                geocodingResults[cluster.id] = address
                logger.info("🔬 [Step 4] → \(address.name)")
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

        // ===== Phase 2: 스마트 분석 (iOS 17+) =====

        if enableSmartAnalysis && currentAnalysisLevel >= .smart {
            logger.info("🔬 [Smart] 스마트 분석 시작 - 레벨: \(self.currentAnalysisLevel.displayName)")

            currentStep = "🤖 스마트 분석 시작..."
            progress = 0.45

            do {
                let smartResult = try await smartCoordinator.runSmartAnalysis(
                    clusters: clusters,
                    basicResult: result,
                    level: currentAnalysisLevel
                )

                // 스마트 분석 결과 병합
                smartCoordinator.mergeResults(smartResult: smartResult, into: &result)

                // 추가 정보 저장 (나중에 UI에서 활용)
                result.smartAnalysisResult = smartResult

                logger.info("🔬 [Smart] 스마트 분석 완료!")
                logger.info("🔬 [Smart] - 스마트 제목: \(smartResult.smartTitle)")
                logger.info("🔬 [Smart] - Vision 분석: \(smartResult.visionClassificationCount)장")
                logger.info("🔬 [Smart] - POI 검색: \(smartResult.poiSearchCount)개")

            } catch {
                logger.warning("🔬 [Smart] 스마트 분석 실패 (기본 결과 사용): \(error.localizedDescription)")
                // 스마트 분석 실패해도 기본 결과는 유지
            }
        }

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
