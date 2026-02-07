import Foundation
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SmartAnalysis")

/// Smart Analysis 코디네이터
/// iOS 버전에 따라 분석 단계를 조율하고 모든 Smart Analysis 서비스를 통합
@MainActor
@Observable
class SmartAnalysisCoordinator {

    // MARK: - Analysis Level

    enum AnalysisLevel: Int, Comparable {
        case basic = 0       // iOS 17: 기본 분석 (Geocoding, Clustering, Activity)
        case smart = 1       // iOS 17: 스마트 분석 (+ Vision, POI, Smart Title)
        case advanced = 2    // iOS 18+: 고급 분석 (+ FastVLM 등 추가 기능)

        static func < (lhs: AnalysisLevel, rhs: AnalysisLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var displayName: String {
            switch self {
            case .basic: return "기본 분석"
            case .smart: return "스마트 분석"
            case .advanced: return "AI 분석"
            }
        }

        var description: String {
            switch self {
            case .basic:
                return "위치 기반 분석"
            case .smart:
                return "장면 인식 + 주변 정보"
            case .advanced:
                return "고급 AI 분석"
            }
        }
    }

    // MARK: - Analysis Progress

    struct AnalysisProgress {
        var currentStep: AnalysisStep
        var stepProgress: Double  // 0.0 ~ 1.0
        var overallProgress: Double
        var statusMessage: String

        static let initial = AnalysisProgress(
            currentStep: .metadata,
            stepProgress: 0,
            overallProgress: 0,
            statusMessage: "준비 중..."
        )
    }

    enum AnalysisStep: Int, CaseIterable {
        case metadata       // 메타데이터 추출
        case clustering     // 장소 클러스터링
        case geocoding      // 역지오코딩
        case vision         // 장면 분류 (iOS 17+)
        case poi            // POI 검색 (iOS 17+)
        case titleGen       // 제목 생성
        case advancedAI     // 고급 AI (iOS 18+)
        case finalizing     // 마무리

        var displayName: String {
            switch self {
            case .metadata: return "사진 정보 읽기"
            case .clustering: return "동선 분석"
            case .geocoding: return "주소 변환"
            case .vision: return "장면 인식"
            case .poi: return "주변 정보 검색"
            case .titleGen: return "제목 생성"
            case .advancedAI: return "AI 분석"
            case .finalizing: return "마무리"
            }
        }

        var emoji: String {
            switch self {
            case .metadata: return "📸"
            case .clustering: return "📊"
            case .geocoding: return "🗺️"
            case .vision: return "👁️"
            case .poi: return "📍"
            case .titleGen: return "📝"
            case .advancedAI: return "🤖"
            case .finalizing: return "✨"
            }
        }

        /// 이 단계의 가중치 (전체 진행률 계산용)
        var weight: Double {
            switch self {
            case .metadata: return 0.05
            case .clustering: return 0.10
            case .geocoding: return 0.25
            case .vision: return 0.20
            case .poi: return 0.15
            case .titleGen: return 0.05
            case .advancedAI: return 0.15
            case .finalizing: return 0.05
            }
        }
    }

    // MARK: - Enhanced Analysis Result

    struct SmartAnalysisResult {
        // 스마트 분석 결과 (basicResult 제거 - 순환 참조 방지)
        var enhancedPlaces: [EnhancedPlace]
        var smartTitle: String
        var smartSubtitle: String
        var analysisLevel: AnalysisLevel
        var dominantScene: VisionAnalysisService.SceneCategory?

        // 통계
        var analysisTime: TimeInterval
        var visionClassificationCount: Int
        var poiSearchCount: Int

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
    }

    struct EnhancedPlace {
        let cluster: PlaceCluster

        // Vision 분석 결과
        var sceneCategory: VisionAnalysisService.SceneCategory?
        var sceneConfidence: Float?

        // POI 결과
        var nearbyHotspots: POIService.NearbyHotspots?
        var betterName: String?  // POI 기반 더 나은 이름

        // 최종 표시용
        var displayName: String {
            betterName ?? cluster.name
        }

        var displayEmoji: String {
            sceneCategory?.emoji ?? cluster.activityType.emoji
        }
    }

    // MARK: - Properties

    var progress = AnalysisProgress.initial
    var isAnalyzing = false
    var error: Error?

    private let visionService = VisionAnalysisService()
    private let poiService = POIService()
    private let titleGenerator = SmartTitleGenerator()

    // Wander Intelligence Services
    private let travelDNAService = TravelDNAService()
    private let momentScoreService = MomentScoreService()
    private let storyWeavingService = StoryWeavingService()
    private let insightEngine = InsightEngine()

    // MARK: - Available Analysis Level

    /// 현재 기기에서 사용 가능한 최대 분석 레벨
    static var availableLevel: AnalysisLevel {
        if #available(iOS 18.0, *) {
            return .advanced
        }
        return .smart
    }

    // MARK: - Run Smart Analysis

    /// 스마트 분석 실행
    /// - Parameters:
    ///   - clusters: 기본 분석으로 생성된 클러스터
    ///   - basicResult: 기본 분석 결과
    ///   - level: 분석 레벨 (nil이면 자동 선택)
    /// - Returns: 스마트 분석 결과
    func runSmartAnalysis(
        clusters: [PlaceCluster],
        basicResult: AnalysisResult,
        level: AnalysisLevel? = nil,
        context: TravelContext = .travel
    ) async throws -> SmartAnalysisResult {
        let targetLevel = level ?? Self.availableLevel
        let startTime = Date()

        logger.info("🔬 [SmartAnalysis] 시작 - 레벨: \(targetLevel.displayName), 클러스터: \(clusters.count)개")

        isAnalyzing = true
        error = nil

        defer {
            isAnalyzing = false
        }

        var enhancedPlaces: [EnhancedPlace] = []
        var visionCount = 0
        var poiCount = 0
        var dominantScene: VisionAnalysisService.SceneCategory?

        // Step 1: Vision 분석 (스마트 레벨 이상)
        if targetLevel >= .smart {
            updateProgress(step: .vision, stepProgress: 0, message: "장면 인식 중...")

            var sceneCounts: [VisionAnalysisService.SceneCategory: Int] = [:]

            for (index, cluster) in clusters.enumerated() {
                // 클러스터 내 사진 장면 분석
                let scene = await visionService.analyzeCluster(assets: cluster.photos, sampleCount: 3)
                visionCount += min(cluster.photos.count, 3)

                sceneCounts[scene, default: 0] += 1

                var enhanced = EnhancedPlace(cluster: cluster)
                enhanced.sceneCategory = scene
                enhancedPlaces.append(enhanced)

                let stepProgress = Double(index + 1) / Double(clusters.count)
                updateProgress(step: .vision, stepProgress: stepProgress, message: "장면 인식 중... (\(index + 1)/\(clusters.count))")
            }

            // 지배적인 장면 카테고리
            dominantScene = sceneCounts.max(by: { $0.value < $1.value })?.key

            logger.info("🔬 [SmartAnalysis] Vision 분석 완료 - \(visionCount)장 분석, 지배 장면: \(dominantScene?.koreanName ?? "없음")")
        } else {
            // 기본 레벨: Vision 분석 없이 클러스터만 변환
            enhancedPlaces = clusters.map { EnhancedPlace(cluster: $0) }
        }

        // Step 2: POI 검색 (스마트 레벨 이상)
        if targetLevel >= .smart {
            updateProgress(step: .poi, stepProgress: 0, message: "주변 정보 검색 중...")

            for (index, var enhanced) in enhancedPlaces.enumerated() {
                let coordinate = enhanced.cluster.coordinate

                // 주변 핫스팟 검색
                let hotspots = await poiService.findNearbyHotspots(coordinate: coordinate)
                enhanced.nearbyHotspots = hotspots
                poiCount += hotspots.totalCount

                // 더 나은 장소명 검색
                if let betterName = await poiService.findBetterPlaceName(
                    coordinate: coordinate,
                    currentName: enhanced.cluster.name
                ) {
                    enhanced.betterName = betterName
                }

                enhancedPlaces[index] = enhanced

                let stepProgress = Double(index + 1) / Double(enhancedPlaces.count)
                updateProgress(step: .poi, stepProgress: stepProgress, message: "주변 정보 검색 중... (\(index + 1)/\(enhancedPlaces.count))")
            }

            logger.info("🔬 [SmartAnalysis] POI 검색 완료 - \(poiCount)개 발견")
        }

        // Step 3: 스마트 제목 생성
        updateProgress(step: .titleGen, stepProgress: 0, message: "제목 생성 중...")

        let titleContext = SmartTitleGenerator.TitleContext(
            places: enhancedPlaces.map { enhanced in
                SmartTitleGenerator.TitleContext.PlaceInfo(
                    name: enhanced.displayName,
                    locality: nil,  // TODO: GeocodingResult에서 가져오기
                    subLocality: nil,
                    sceneCategory: enhanced.sceneCategory,
                    activityType: enhanced.cluster.activityType,
                    photoCount: enhanced.cluster.photos.count
                )
            },
            startDate: basicResult.startDate,
            endDate: basicResult.endDate,
            totalDistance: basicResult.totalDistance,
            photoCount: basicResult.photoCount,
            dominantSceneCategory: dominantScene,
            analysisLevel: VisionAnalysisService.availableAnalysisLevel
        )

        let smartTitle = titleGenerator.generateTitle(from: titleContext)
        let smartSubtitle = titleGenerator.generateSubtitle(from: titleContext)

        updateProgress(step: .titleGen, stepProgress: 1.0, message: "제목 생성 완료")

        logger.info("🔬 [SmartAnalysis] 제목 생성 완료: \(smartTitle)")

        // Step 4: Wander Intelligence 분석
        // NOTE: 연구 문서 Section 7.4에 따라 TravelDNA/TripScore/MomentScore는 UI에 노출하지 않음
        // StoryWeaving과 InsightEngine은 여행/혼합 컨텍스트에서만 실행
        var travelDNA: TravelDNAService.TravelDNA?
        var momentScores: [MomentScoreService.MomentScore] = []
        var tripScore: MomentScoreService.TripOverallScore?
        var travelStory: StoryWeavingService.TravelStory?
        var insights: [InsightEngine.TravelInsight] = []
        var insightSummary: InsightEngine.InsightSummary?

        let shouldRunWanderIntelligence = (context == .travel || context == .mixed)

        if shouldRunWanderIntelligence {
            updateProgress(step: .advancedAI, stepProgress: 0, message: "여행 분석 중...")

            // 4-1: TravelDNA 분석 (스토리/인사이트 입력용 내부 데이터, UI 미노출)
            let sceneCategories = enhancedPlaces.map { $0.sceneCategory }
            travelDNA = travelDNAService.analyzeDNA(from: clusters, sceneCategories: sceneCategories)
            logger.info("🧬 [WanderIntelligence] TravelDNA 분석 완료: \(travelDNA?.primaryType.koreanName ?? "N/A")")

            updateProgress(step: .advancedAI, stepProgress: 0.2, message: "순간 점수 계산 중...")

            // 4-2: MomentScore 계산 (스토리/인사이트 입력용 내부 데이터, UI 미노출)
            for (index, enhanced) in enhancedPlaces.enumerated() {
                let score = momentScoreService.calculateScore(
                    for: enhanced.cluster,
                    sceneCategory: enhanced.sceneCategory,
                    nearbyHotspots: enhanced.nearbyHotspots,
                    allClusters: clusters
                )
                momentScores.append(score)
                logger.info("⭐ [WanderIntelligence] \(enhanced.cluster.name): \(score.totalScore)점 (\(score.grade.koreanName))")

                let progress = 0.2 + (0.2 * Double(index + 1) / Double(enhancedPlaces.count))
                updateProgress(step: .advancedAI, stepProgress: progress, message: "순간 점수 계산 중... (\(index + 1)/\(enhancedPlaces.count))")
            }

            // 4-3: 전체 여행 점수 (내부 데이터, UI 미노출)
            tripScore = momentScoreService.calculateTripScore(momentScores: momentScores)
            logger.info("🏆 [WanderIntelligence] 여행 종합 점수: \(tripScore?.averageScore ?? 0)점")

            updateProgress(step: .advancedAI, stepProgress: 0.5, message: "스토리 생성 중...")

            // 4-4: StoryWeaving (스토리 생성)
            let sceneDescriptions = sceneCategories.compactMap { $0?.koreanName }
            let storyContext = StoryWeavingService.StoryContext(
                clusters: clusters,
                travelDNA: travelDNA,
                momentScores: momentScores,
                sceneDescriptions: sceneDescriptions,
                startDate: basicResult.startDate,
                endDate: basicResult.endDate,
                totalDistance: basicResult.totalDistance,
                photoCount: basicResult.photoCount
            )
            travelStory = storyWeavingService.generateStory(from: storyContext)
            logger.info("📖 [WanderIntelligence] 스토리 생성 완료: \(travelStory?.title ?? "N/A")")

            updateProgress(step: .advancedAI, stepProgress: 0.7, message: "인사이트 발굴 중...")

            // 4-5: InsightEngine (인사이트 발굴)
            let insightContext = InsightEngine.AnalysisContext(
                clusters: clusters,
                sceneCategories: sceneCategories,
                momentScores: momentScores,
                travelDNA: travelDNA,
                totalDistance: basicResult.totalDistance * 1000, // km → m
                totalPhotos: basicResult.photoCount
            )
            insights = insightEngine.discoverInsights(from: insightContext)
            insightSummary = insightEngine.generateSummary(from: insights)
            logger.info("🔍 [WanderIntelligence] 인사이트 발굴 완료: \(insights.count)개")

            // 4-6: iOS 18.2+ FastVLM 고급 분석 (선택적)
            if targetLevel >= .advanced {
                if #available(iOS 18.2, *) {
                    updateProgress(step: .advancedAI, stepProgress: 0.85, message: "고급 AI 분석 중...")
                    logger.info("🤖 [WanderIntelligence] iOS 18.2+ FastVLM 분석 준비 완료")
                }
            }

            updateProgress(step: .advancedAI, stepProgress: 1.0, message: "AI 분석 완료")
            logger.info("✨ [WanderIntelligence] 전체 분석 완료!")
        } else {
            logger.info("⏭️ [WanderIntelligence] \(context.displayName) 컨텍스트 → Wander Intelligence 건너뜀")
            updateProgress(step: .advancedAI, stepProgress: 1.0, message: "분석 완료")
        }

        // Step 5: 마무리
        updateProgress(step: .finalizing, stepProgress: 1.0, message: "완료!")

        let analysisTime = Date().timeIntervalSince(startTime)

        // 결과 조합
        let result = SmartAnalysisResult(
            enhancedPlaces: enhancedPlaces,
            smartTitle: smartTitle,
            smartSubtitle: smartSubtitle,
            analysisLevel: targetLevel,
            dominantScene: dominantScene,
            analysisTime: analysisTime,
            visionClassificationCount: visionCount,
            poiSearchCount: poiCount,
            travelDNA: travelDNA,
            momentScores: momentScores,
            tripScore: tripScore,
            travelStory: travelStory,
            insights: insights,
            insightSummary: insightSummary
        )

        logger.info("🔬 [SmartAnalysis] 완료! 소요시간: \(String(format: "%.2f", analysisTime))초")

        return result
    }

    // MARK: - Progress Update

    private func updateProgress(step: AnalysisStep, stepProgress: Double, message: String) {
        // 이전 단계들의 누적 가중치 계산
        var cumulativeWeight: Double = 0
        for s in AnalysisStep.allCases {
            if s.rawValue < step.rawValue {
                cumulativeWeight += s.weight
            } else {
                break
            }
        }

        // 현재 단계 진행률 포함한 전체 진행률
        let overallProgress = cumulativeWeight + (step.weight * stepProgress)

        progress = AnalysisProgress(
            currentStep: step,
            stepProgress: stepProgress,
            overallProgress: min(overallProgress, 1.0),
            statusMessage: "\(step.emoji) \(message)"
        )
    }
}

// MARK: - Integration with AnalysisEngine

extension SmartAnalysisCoordinator {
    /// 기존 AnalysisResult에 스마트 분석 결과 병합
    func mergeResults(
        smartResult: SmartAnalysisResult,
        into basicResult: inout AnalysisResult
    ) {
        // 제목 업데이트
        basicResult.title = smartResult.smartTitle

        // 클러스터 정보 업데이트
        for enhanced in smartResult.enhancedPlaces {
            if let index = basicResult.places.firstIndex(where: { $0.id == enhanced.cluster.id }) {
                // 더 나은 이름으로 업데이트
                if let betterName = enhanced.betterName {
                    basicResult.places[index].name = betterName
                    basicResult.places[index].betterName = betterName
                }

                // Vision 결과 저장
                if let scene = enhanced.sceneCategory {
                    basicResult.places[index].sceneCategory = scene
                    basicResult.places[index].sceneConfidence = enhanced.sceneConfidence

                    // 활동 타입 업데이트 (Vision 결과 기반)
                    if scene != .unknown {
                        basicResult.places[index].activityType = scene.toActivityType
                    }
                }

                // 주변 핫스팟 저장
                basicResult.places[index].nearbyHotspots = enhanced.nearbyHotspots
            }
        }

        // MARK: - Wander Intelligence 결과 병합

        // TravelDNA
        basicResult.travelDNA = smartResult.travelDNA

        // MomentScores
        basicResult.momentScores = smartResult.momentScores

        // Trip Score
        basicResult.tripScore = smartResult.tripScore

        // Travel Story
        basicResult.travelStory = smartResult.travelStory

        // Insights
        basicResult.insights = smartResult.insights
        basicResult.insightSummary = smartResult.insightSummary
    }
}
