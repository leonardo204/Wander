import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoSelectionVM")

enum QuickSelectRange: String, CustomStringConvertible {
    case today = "오늘"
    case thisWeek = "이번 주"
    case thisMonth = "이번 달"
    case last3Months = "최근 3개월"
    case all = "전체"
    case custom = "직접 선택"

    var description: String {
        return rawValue
    }
}

@Observable
class PhotoSelectionViewModel {
    // MARK: - Properties
    var photos: [PHAsset] = []
    var selectedAssets: [PHAsset] = []
    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate: Date = Date()
    var quickSelect: QuickSelectRange = .thisMonth

    var showAnalysis = false
    var analysisResult: AnalysisResult?

    /// 분석 완료 후 PhotoSelectionView도 닫아야 할 때 true로 설정
    var shouldDismissPhotoSelection = false

    // MARK: - Computed Properties
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        // 같은 날이면 하나만 표시
        if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            return formatter.string(from: startDate)
        }
        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: endDate))"
    }

    var selectedPhotosInfo: String {
        let withGPS = selectedAssets.filter { $0.location != nil }.count
        return "GPS 정보 있음: \(withGPS)장"
    }

    // MARK: - Permission
    func checkPermission() {
        logger.info("📷 [VM] checkPermission 호출")
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        logger.info("📷 [VM] 현재 권한 상태: \(String(describing: self.authorizationStatus))")

        if authorizationStatus == .notDetermined {
            logger.info("📷 [VM] 권한 요청 중...")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    logger.info("📷 [VM] 권한 응답: \(String(describing: status))")
                    self?.authorizationStatus = status
                    if status == .authorized || status == .limited {
                        self?.fetchPhotos()
                    }
                }
            }
        } else if authorizationStatus == .authorized || authorizationStatus == .limited {
            fetchPhotos()
        }
    }

    // MARK: - Fetch Photos
    func fetchPhotos() {
        logger.info("📷 [VM] fetchPhotos 호출 - 기간: \(self.startDate) ~ \(self.endDate)")
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        logger.info("📷 [VM] fetch 결과: \(result.count)장")

        var assets: [PHAsset] = []
        var withGPS = 0
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
            if asset.location != nil {
                withGPS += 1
            }
        }
        logger.info("📷 [VM] GPS 있는 사진: \(withGPS)장")

        DispatchQueue.main.async {
            self.photos = assets
        }
    }

    // MARK: - Quick Select
    func selectQuickRange(_ range: QuickSelectRange) {
        quickSelect = range
        let calendar = Calendar.current
        let now = Date()

        switch range {
        case .today:
            startDate = calendar.startOfDay(for: now)
            endDate = now

        case .thisWeek:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            startDate = weekStart
            endDate = now

        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            startDate = monthStart
            endDate = now

        case .last3Months:
            startDate = calendar.date(byAdding: .month, value: -3, to: now)!
            endDate = now

        case .all:
            startDate = calendar.date(byAdding: .year, value: -10, to: now)!
            endDate = now

        case .custom:
            break
        }

        fetchPhotos()
    }

    // MARK: - Selection
    func toggleSelection(_ asset: PHAsset) {
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        } else {
            selectedAssets.append(asset)
        }
    }

    func addToSelection(_ asset: PHAsset) {
        if !selectedAssets.contains(asset) {
            selectedAssets.append(asset)
        }
    }

    func removeFromSelection(_ asset: PHAsset) {
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        }
    }

    func selectionOrder(for asset: PHAsset) -> Int? {
        guard let index = selectedAssets.firstIndex(of: asset) else { return nil }
        return index + 1
    }

    func clearSelection() {
        selectedAssets.removeAll()
    }

    func selectAll() {
        selectedAssets = photos
        let count = photos.count
        logger.info("📷 [VM] 전체 선택: \(count)장")
    }

    // MARK: - Analysis
    func startAnalysis() {
        guard !selectedAssets.isEmpty else { return }
        showAnalysis = true
    }
}

// MARK: - Analysis Result Model
struct AnalysisResult {
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()

    /// 결과 화면 레이아웃 타입 (timeline, magazine, grid)
    var layoutType: String = "timeline"

    /// 여행 테마 (예: "식도락", "힐링", "액티비티" 등)
    var theme: String?

    var places: [PlaceCluster] = []
    var totalDistance: Double = 0
    var photoCount: Int = 0

    /// Vision SDK로 추출된 감성 키워드 (SNS 공유용)
    var keywords: [String] = []

    /// 스마트 분석 결과 (iOS 17+)
    var smartAnalysisResult: SmartAnalysisCoordinator.SmartAnalysisResult?

    // MARK: - v3.1 Context Classification

    /// 기록 Context (일상/외출/여행/혼합)
    var context: TravelContext = .travel

    /// Context 분류 신뢰도 (0.0~1.0)
    var contextConfidence: Double = 0.0

    /// Context 분류 근거
    var contextReasoning: String?

    /// 혼합 Context 정보 (분리 필요 시)
    var mixedContextInfo: MixedContextInfo?

    // MARK: - Wander Intelligence Results

    /// 여행자 DNA 분석 결과
    var travelDNA: TravelDNAService.TravelDNA?

    /// 각 장소별 MomentScore
    var momentScores: [MomentScoreService.MomentScore] = []

    /// 전체 여행 점수
    var tripScore: MomentScoreService.TripOverallScore?

    /// AI 스토리
    var travelStory: StoryWeavingService.TravelStory?

    /// 발견된 인사이트
    var insights: [InsightEngine.TravelInsight] = []

    /// 인사이트 요약
    var insightSummary: InsightEngine.InsightSummary?

    // MARK: - AI Enhancement State

    /// AI 다듬기 적용 여부
    var isAIEnhanced: Bool = false

    /// AI 다듬기 적용 시간
    var aiEnhancedAt: Date?

    /// AI 다듬기에 사용된 프로바이더명
    var aiEnhancedProvider: String?

    /// AI가 다듬은 TravelDNA 설명 (computed property 오버레이)
    /// TravelDNA.description은 primaryType의 computed property이므로
    /// AI 결과를 별도 필드에 저장하고 UI에서 우선 사용
    var aiEnhancedDNADescription: String?

    var placeCount: Int {
        places.count
    }

    /// 스마트 서브타이틀 (있으면 사용, 없으면 기본 생성)
    var subtitle: String {
        if let smart = smartAnalysisResult {
            return smart.smartSubtitle
        }
        // 기본 서브타이틀
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return "\(formatter.string(from: startDate)) · \(placeCount)곳"
    }

    /// 분석 레벨 표시
    var analysisLevelBadge: String? {
        guard let level = smartAnalysisResult?.analysisLevel else { return nil }
        switch level {
        case .basic: return nil
        case .smart: return "스마트 분석"
        case .advanced: return "AI 분석"
        }
    }

    /// 지배적인 장면 카테고리
    var dominantScene: VisionAnalysisService.SceneCategory? {
        smartAnalysisResult?.dominantScene
    }

    /// 하이라이트 순간 (가장 높은 점수 장소)
    var highlightMoment: (place: PlaceCluster, score: MomentScoreService.MomentScore)? {
        guard !momentScores.isEmpty, momentScores.count == places.count else { return nil }
        if let maxIndex = momentScores.indices.max(by: { momentScores[$0].totalScore < momentScores[$1].totalScore }) {
            return (places[maxIndex], momentScores[maxIndex])
        }
        return nil
    }

    /// 전설적인 순간들
    var legendaryMoments: [(place: PlaceCluster, score: MomentScoreService.MomentScore)] {
        guard momentScores.count == places.count else { return [] }
        return zip(places, momentScores)
            .filter { $0.1.grade == .legendary }
            .map { ($0.0, $0.1) }
    }

    /// 획득한 모든 배지
    var allBadges: [MomentScoreService.SpecialBadge] {
        Array(Set(momentScores.flatMap { $0.specialBadges }))
    }
    
    /// Wander Intelligence 데이터 유무
    /// NOTE: 연구 문서 Section 7.4에 따라 TravelDNA/TripScore는 UI에 노출하지 않음
    /// 실제 UI에 표시되는 스토리+인사이트만 체크
    var hasWanderIntelligence: Bool {
        travelStory != nil || !insights.isEmpty
    }
}

// MARK: - Place Cluster Model
class PlaceCluster: Identifiable, Hashable {
    let id = UUID()
    var name: String = ""
    var address: String = ""
    var latitude: Double
    var longitude: Double
    var placeType: String?
    var activityType: ActivityType = .other
    var startTime: Date
    var endTime: Date?
    var photos: [PHAsset] = []
    var userPlaceMatched: Bool = false  // 사용자 등록 장소와 매칭됨

    // MARK: - v3.1 Context Classification (행정구역 정보)

    /// 시/도 (예: 서울특별시, 경기도)
    var administrativeArea: String?

    /// 시/군/구 (예: 강남구, 성남시)
    var locality: String?

    /// 읍/면/동 (예: 역삼동, 분당동)
    var subLocality: String?

    // MARK: - Smart Analysis Results (iOS 17+)

    /// Vision 분석 장면 카테고리
    var sceneCategory: VisionAnalysisService.SceneCategory?

    /// Vision 분석 신뢰도
    var sceneConfidence: Float?

    /// 주변 핫스팟 (카페, 맛집, 명소)
    var nearbyHotspots: POIService.NearbyHotspots?

    /// POI 기반 더 나은 장소명
    var betterName: String?

    init(latitude: Double, longitude: Double, startTime: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.startTime = startTime
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 클러스터 중심 좌표 (coordinate의 별칭, InsightEngine 호환성)
    var centerCoordinate: CLLocationCoordinate2D {
        coordinate
    }

    /// GPS 좌표가 유효한지 확인 (0,0은 유효하지 않음 - 미분류 사진)
    var hasValidCoordinate: Bool {
        // (0, 0)은 대서양 중간이므로 유효하지 않은 좌표로 간주
        // 또한 매우 작은 값 (거의 0에 가까운)도 필터링
        return abs(latitude) > 0.0001 || abs(longitude) > 0.0001
    }

    /// 최종 표시용 이름 (betterName 우선)
    var displayName: String {
        betterName ?? name
    }

    /// 최종 표시용 이모지 (sceneCategory 우선)
    var displayEmoji: String {
        sceneCategory?.emoji ?? activityType.emoji
    }

    func addPhoto(_ asset: PHAsset) {
        photos.append(asset)
        if let creationDate = asset.creationDate {
            if creationDate > (endTime ?? startTime) {
                endTime = creationDate
            }
        }
    }

    // MARK: - Hashable
    static func == (lhs: PlaceCluster, rhs: PlaceCluster) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Activity Type
enum ActivityType: String, CaseIterable, Identifiable {
    case cafe
    case restaurant
    case beach
    case mountain
    case tourist
    case shopping
    case culture
    case airport
    case nature
    case nightlife
    case transportation
    case accommodation
    case unknown
    case other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .cafe: return "☕"
        case .restaurant: return "🍽️"
        case .beach: return "🏖️"
        case .mountain: return "⛰️"
        case .tourist: return "🏛️"
        case .shopping: return "🛍️"
        case .culture: return "🎭"
        case .airport: return "✈️"
        case .nature: return "🌲"
        case .nightlife: return "🌙"
        case .transportation: return "🚗"
        case .accommodation: return "🏨"
        case .unknown: return "📍"
        case .other: return "📍"
        }
    }

    var displayName: String {
        switch self {
        case .cafe: return "카페"
        case .restaurant: return "식사"
        case .beach: return "해변"
        case .mountain: return "등산"
        case .tourist: return "관광"
        case .shopping: return "쇼핑"
        case .culture: return "문화"
        case .airport: return "공항"
        case .nature: return "자연"
        case .nightlife: return "나이트라이프"
        case .transportation: return "이동"
        case .accommodation: return "숙소"
        case .unknown: return "기타"
        case .other: return "기타"
        }
    }

    var color: Color {
        switch self {
        case .cafe: return WanderColors.activityCafe
        case .restaurant: return WanderColors.activityRestaurant
        case .beach: return WanderColors.activityBeach
        case .mountain: return WanderColors.activityMountain
        case .tourist: return WanderColors.activityTourist
        case .shopping: return WanderColors.activityShopping
        case .culture: return WanderColors.activityCulture
        case .airport: return WanderColors.activityAirport
        case .nature: return WanderColors.activityMountain
        case .nightlife: return WanderColors.activityCulture
        case .transportation: return WanderColors.activityAirport
        case .accommodation: return WanderColors.surface
        case .unknown: return WanderColors.surface
        case .other: return WanderColors.surface
        }
    }
}

import CoreLocation
