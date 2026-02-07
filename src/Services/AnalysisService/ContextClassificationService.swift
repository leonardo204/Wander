import Foundation
import CoreLocation
import SwiftyH3
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ContextClassification")

// MARK: - Travel Context

/// 기록 Context 유형 (v3.1~)
/// 일상/외출/여행을 구분하여 UI 및 분석 결과를 차별화
enum TravelContext: String, Codable, CaseIterable {
    case daily = "daily"       // 🏠 일상
    case outing = "outing"     // 🚶 외출
    case travel = "travel"     // ✈️ 여행
    case mixed = "mixed"       // 🔀 혼합 (분리 필요)

    var displayName: String {
        switch self {
        case .daily: return "일상"
        case .outing: return "외출"
        case .travel: return "여행"
        case .mixed: return "혼합"
        }
    }

    var emoji: String {
        switch self {
        case .daily: return "🏠"
        case .outing: return "🚶"
        case .travel: return "✈️"
        case .mixed: return "🔀"
        }
    }

    var badgeColor: String {
        switch self {
        case .daily: return "contextDaily"
        case .outing: return "contextOuting"
        case .travel: return "contextTravel"
        case .mixed: return "contextMixed"
        }
    }
}

// MARK: - H3 Distance Level (v3.2: H3 헥사곤 기반)

/// H3 해상도 기반 거리 레벨
/// H3 셀 비교는 오프라인 순수 문자열 비교 (네트워크 불필요)
enum H3DistanceLevel: Int, Comparable {
    case sameBuilding = 0      // H3 res 9 일치 (~0.11 km²)
    case sameNeighborhood = 1  // H3 res 7 일치 (~5.16 km²)
    case sameCity = 2          // H3 res 5 일치 (~253 km²)
    case sameProvince = 3      // H3 res 4 일치 (~1,770 km²)
    case differentProvince = 4 // H3 어떤 해상도도 불일치

    static func < (lhs: H3DistanceLevel, rhs: H3DistanceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .sameBuilding: return "같은 건물"
        case .sameNeighborhood: return "같은 동네"
        case .sameCity: return "같은 시/군"
        case .sameProvince: return "같은 시/도"
        case .differentProvince: return "다른 시/도"
        }
    }
}

// MARK: - Classification Result

/// Context 분류 결과
struct ContextClassificationResult {
    let context: TravelContext
    let confidence: Double
    let distanceLevel: H3DistanceLevel
    let reasoning: String

    /// 혼합 상태인 경우 분리 정보
    var mixedInfo: MixedContextInfo?
}

/// 혼합 Context 정보 (일상 + 여행이 섞인 경우)
struct MixedContextInfo {
    let dailyClusters: [UUID]   // 일상으로 분류된 클러스터 ID
    let travelClusters: [UUID]  // 여행으로 분류된 클러스터 ID
    let dailyPhotoCount: Int
    let travelPhotoCount: Int
}

// MARK: - Cluster H3 Info (v3.2: H3 셀 기반)

/// 클러스터의 H3 셀 정보
struct ClusterH3Info {
    let clusterId: UUID
    let h3CellRes4: String
    let h3CellRes5: String
    let h3CellRes7: String
    let h3CellRes9: String
    let coordinate: CLLocationCoordinate2D
    let photoCount: Int
    let dateRange: ClosedRange<Date>

    /// H3 거리 레벨 계산 (기준 장소 대비)
    /// 오프라인, 순수 문자열 비교
    func distanceLevel(from basePlace: UserPlace) -> H3DistanceLevel {
        guard let baseRes9 = basePlace.h3CellRes9,
              let baseRes7 = basePlace.h3CellRes7,
              let baseRes5 = basePlace.h3CellRes5,
              let baseRes4 = basePlace.h3CellRes4 else {
            // H3 인덱스 없는 장소 → 좌표 거리 기반 폴백
            return fallbackDistanceLevel(from: basePlace)
        }

        if h3CellRes9 == baseRes9 { return .sameBuilding }
        if h3CellRes7 == baseRes7 { return .sameNeighborhood }
        if h3CellRes5 == baseRes5 { return .sameCity }
        if h3CellRes4 == baseRes4 { return .sameProvince }
        return .differentProvince
    }

    /// H3 인덱스 없는 장소에 대한 좌표 거리 기반 폴백
    private func fallbackDistanceLevel(from basePlace: UserPlace) -> H3DistanceLevel {
        let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: basePlace.latitude, longitude: basePlace.longitude))

        if distance < 500 { return .sameBuilding }       // 500m 이내
        if distance < 5_000 { return .sameNeighborhood }  // 5km 이내
        if distance < 30_000 { return .sameCity }         // 30km 이내
        if distance < 100_000 { return .sameProvince }    // 100km 이내
        return .differentProvince
    }

    /// GPS 좌표에서 ClusterH3Info 생성 (SwiftyH3 사용)
    static func from(
        clusterId: UUID,
        coordinate: CLLocationCoordinate2D,
        photoCount: Int,
        dateRange: ClosedRange<Date>
    ) -> ClusterH3Info {
        let h3LatLng = coordinate.h3LatLng
        return ClusterH3Info(
            clusterId: clusterId,
            h3CellRes4: (try? h3LatLng.cell(at: .res4).description) ?? "",
            h3CellRes5: (try? h3LatLng.cell(at: .res5).description) ?? "",
            h3CellRes7: (try? h3LatLng.cell(at: .res7).description) ?? "",
            h3CellRes9: (try? h3LatLng.cell(at: .res9).description) ?? "",
            coordinate: coordinate,
            photoCount: photoCount,
            dateRange: dateRange
        )
    }
}

// MARK: - Context Classification Service (v3.2: H3 기반)

/// Context Classification 서비스
/// H3 헥사곤 그리드로 오프라인 즉시 분류, CLGeocoder는 경계 케이스만
@MainActor
class ContextClassificationService {

    // MARK: - Main Classification

    /// 클러스터들을 분석하여 Context 분류
    func classify(
        clusterInfos: [ClusterH3Info],
        userPlaces: [UserPlace],
        learnedPlaces: [LearnedPlace] = []
    ) -> ContextClassificationResult {
        logger.info("🏷️ [Context] H3 분류 시작 - 클러스터: \(clusterInfos.count)개, 등록장소: \(userPlaces.count)개")

        // 기준 장소 필터링 (H3 인덱스가 있는 집/회사/학교)
        var basePlaces = userPlaces.filter { place in
            place.placeType.isBaseLocation && place.hasH3Indices
        }

        // 기준 장소가 없으면 학습된 장소에서 확인된 것 사용
        if basePlaces.isEmpty {
            let confirmedLearned = learnedPlaces.filter { $0.isConfirmed && !$0.isIgnored }
            if !confirmedLearned.isEmpty {
                logger.info("🏷️ [Context] 등록 장소 없음, 학습된 장소 \(confirmedLearned.count)개 사용")
                // LearnedPlace → 임시 UserPlace 변환 (H3 인덱스 포함)
                basePlaces = confirmedLearned.map { learned in
                    let place = UserPlace(
                        name: learned.displayName ?? "학습 장소",
                        icon: "📊",
                        latitude: learned.latitude,
                        longitude: learned.longitude,
                        address: "",
                        placeType: learned.suggestedType ?? .custom
                    )
                    place.h3CellRes4 = learned.h3CellRes4
                    place.h3CellRes5 = learned.h3CellRes5
                    place.h3CellRes7 = learned.h3CellRes7
                    place.h3CellRes9 = learned.h3CellRes9
                    return place
                }
            }
        }

        // 기준 장소가 여전히 없으면 기본 분석
        guard !basePlaces.isEmpty else {
            logger.info("🏷️ [Context] 기준 장소 없음 → 기본 분석 수행")
            return classifyWithoutBasePlace(clusterInfos: clusterInfos)
        }

        // 각 클러스터의 H3 거리 레벨 계산
        var clusterLevels: [(info: ClusterH3Info, level: H3DistanceLevel)] = []

        for info in clusterInfos {
            let minLevel = basePlaces
                .map { info.distanceLevel(from: $0) }
                .min() ?? .differentProvince

            clusterLevels.append((info, minLevel))
            logger.info("🏷️ [Context] 클러스터 \(info.clusterId.uuidString.prefix(8)): \(minLevel.description) (H3)")
        }

        // 기간 계산
        let allDates = clusterInfos.flatMap { [$0.dateRange.lowerBound, $0.dateRange.upperBound] }
        let dayCount = calculateDayCount(dates: allDates)

        // 분류 규칙 적용
        return applyClassificationRules(clusterLevels: clusterLevels, dayCount: dayCount)
    }

    // MARK: - Classification Rules

    private func applyClassificationRules(
        clusterLevels: [(info: ClusterH3Info, level: H3DistanceLevel)],
        dayCount: Int
    ) -> ContextClassificationResult {
        let nearClusters = clusterLevels.filter { $0.level <= .sameNeighborhood }
        let farClusters = clusterLevels.filter { $0.level >= .differentProvince }

        let totalClusters = clusterLevels.count
        let nearRatio = Double(nearClusters.count) / Double(totalClusters)
        let farRatio = Double(farClusters.count) / Double(totalClusters)

        logger.info("🏷️ [Context] 분석 - 가까움: \(nearClusters.count), 멀리: \(farClusters.count), 기간: \(dayCount)일")

        // 규칙 1: 혼합 감지 (가까운 곳 + 먼 곳 둘 다 있음)
        if !nearClusters.isEmpty && !farClusters.isEmpty {
            logger.info("🏷️ [Context] → 혼합 감지 (일상 + 여행 혼합)")
            return ContextClassificationResult(
                context: .mixed,
                confidence: 0.8,
                distanceLevel: .differentProvince,
                reasoning: "일상 장소와 여행 장소가 함께 포함되어 있습니다",
                mixedInfo: MixedContextInfo(
                    dailyClusters: nearClusters.map { $0.info.clusterId },
                    travelClusters: farClusters.map { $0.info.clusterId },
                    dailyPhotoCount: nearClusters.reduce(0) { $0 + $1.info.photoCount },
                    travelPhotoCount: farClusters.reduce(0) { $0 + $1.info.photoCount }
                )
            )
        }

        // 규칙 2: 🏠 일상 (H3 res7 일치 + 1일 이내)
        if nearRatio >= 0.8 && dayCount <= 1 {
            logger.info("🏷️ [Context] → 일상 (H3 동네 일치 + 당일)")
            return ContextClassificationResult(
                context: .daily,
                confidence: min(0.95, nearRatio),
                distanceLevel: .sameNeighborhood,
                reasoning: "등록된 장소 근처에서 하루 동안 촬영된 사진입니다"
            )
        }

        // 규칙 3: 🚶 외출 (H3 res5 일치 + 당일치기)
        let sameCityRatio = Double(clusterLevels.filter { $0.level <= .sameCity }.count) / Double(totalClusters)
        if sameCityRatio >= 0.8 && dayCount <= 1 {
            logger.info("🏷️ [Context] → 외출 (H3 시/군 일치 + 당일)")
            return ContextClassificationResult(
                context: .outing,
                confidence: min(0.9, sameCityRatio),
                distanceLevel: .sameCity,
                reasoning: "같은 지역에서 당일치기로 촬영된 사진입니다"
            )
        }

        // 규칙 4: ✈️ 여행 (H3 res4 불일치 or 2일 이상)
        let hasFarPlace = clusterLevels.contains { $0.level >= .differentProvince }
        if farRatio >= 0.5 || dayCount >= 2 || hasFarPlace {
            logger.info("🏷️ [Context] → 여행 (H3 시/도 불일치 or 장기)")
            return ContextClassificationResult(
                context: .travel,
                confidence: min(0.95, max(farRatio, Double(dayCount) / 5.0)),
                distanceLevel: farClusters.first?.level ?? .differentProvince,
                reasoning: dayCount >= 2
                    ? "\(dayCount)일간의 여행 기록입니다"
                    : "멀리 떨어진 장소를 방문한 여행 기록입니다"
            )
        }

        // 기본값: 외출
        logger.info("🏷️ [Context] → 외출 (기본)")
        return ContextClassificationResult(
            context: .outing,
            confidence: 0.7,
            distanceLevel: .sameCity,
            reasoning: "일반적인 외출 기록입니다"
        )
    }

    // MARK: - Without Base Place

    /// 기준 장소 없이 분류 (거리/기간 기반 폴백)
    private func classifyWithoutBasePlace(clusterInfos: [ClusterH3Info]) -> ContextClassificationResult {
        guard !clusterInfos.isEmpty else {
            return ContextClassificationResult(
                context: .daily,
                confidence: 0.5,
                distanceLevel: .sameNeighborhood,
                reasoning: "분석할 장소가 없습니다"
            )
        }

        // 기간 계산
        let allDates = clusterInfos.flatMap { [$0.dateRange.lowerBound, $0.dateRange.upperBound] }
        let dayCount = calculateDayCount(dates: allDates)

        // 총 이동 거리 계산
        let totalDistance = calculateTotalDistance(clusterInfos: clusterInfos)

        // H3 res4 다양성 확인 (다른 시/도가 있는지)
        let uniqueRes4 = Set(clusterInfos.map { $0.h3CellRes4 })

        logger.info("🏷️ [Context] 기준 장소 없음 - 기간: \(dayCount)일, 거리: \(Int(totalDistance/1000))km, H3 res4 종류: \(uniqueRes4.count)")

        // 다른 시/도가 2개 이상 or 2일+ or 50km+
        if uniqueRes4.count >= 2 || dayCount >= 2 || totalDistance >= 50_000 {
            return ContextClassificationResult(
                context: .travel,
                confidence: 0.8,
                distanceLevel: totalDistance >= 50_000 ? .differentProvince : .sameProvince,
                reasoning: "장소 등록 후 더 정확한 분류가 가능합니다"
            )
        }

        // 1일 + 근거리
        if dayCount == 1 && totalDistance < 20_000 {
            return ContextClassificationResult(
                context: .outing,
                confidence: 0.7,
                distanceLevel: .sameCity,
                reasoning: "당일치기 외출로 추정됩니다"
            )
        }

        // 기본: 외출
        return ContextClassificationResult(
            context: .outing,
            confidence: 0.6,
            distanceLevel: .sameCity,
            reasoning: "집/회사 등록 후 더 정확한 분류가 가능합니다"
        )
    }

    // MARK: - Helpers

    private func calculateDayCount(dates: [Date]) -> Int {
        guard let minDate = dates.min(), let maxDate = dates.max() else { return 1 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: minDate), to: calendar.startOfDay(for: maxDate)).day ?? 0
        return max(1, days + 1)
    }

    private func calculateTotalDistance(clusterInfos: [ClusterH3Info]) -> CLLocationDistance {
        guard clusterInfos.count > 1 else { return 0 }

        var total: CLLocationDistance = 0
        for i in 0..<(clusterInfos.count - 1) {
            let from = CLLocation(latitude: clusterInfos[i].coordinate.latitude, longitude: clusterInfos[i].coordinate.longitude)
            let to = CLLocation(latitude: clusterInfos[i+1].coordinate.latitude, longitude: clusterInfos[i+1].coordinate.longitude)
            total += from.distance(from: to)
        }
        return total
    }
}
