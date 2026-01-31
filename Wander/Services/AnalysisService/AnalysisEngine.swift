import Foundation
import Photos
import CoreLocation

@Observable
class AnalysisEngine {
    // MARK: - Properties
    var progress: Double = 0
    var currentStep: String = ""
    var isAnalyzing: Bool = false
    var error: AnalysisError?

    private let geocodingService = GeocodingService()
    private let clusteringService = ClusteringService()
    private let activityService = ActivityInferenceService()

    // MARK: - Analyze
    func analyze(assets: [PHAsset]) async throws -> AnalysisResult {
        isAnalyzing = true
        progress = 0
        error = nil

        defer { isAnalyzing = false }

        // Step 1: Extract metadata
        currentStep = "📸 사진 메타데이터 읽는 중..."
        progress = 0.1

        let photosWithMetadata = extractMetadata(from: assets)
        try await Task.sleep(nanoseconds: 500_000_000) // Visual feedback

        // Step 2: Filter photos with GPS
        currentStep = "📍 위치 정보 추출 중..."
        progress = 0.25

        let gpsPhotos = photosWithMetadata.filter { $0.hasGPS }
        let sortedPhotos = gpsPhotos.sorted { ($0.capturedAt ?? Date()) < ($1.capturedAt ?? Date()) }

        if sortedPhotos.isEmpty {
            throw AnalysisError.noGPSData
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        // Step 3: Clustering
        currentStep = "📊 동선 분석 중..."
        progress = 0.4

        let clusters = clusteringService.cluster(photos: sortedPhotos)
        try await Task.sleep(nanoseconds: 500_000_000)

        // Step 4: Reverse geocoding
        currentStep = "🗺️ 주소 정보 변환 중..."
        progress = 0.6

        for (index, cluster) in clusters.enumerated() {
            do {
                let address = try await geocodingService.reverseGeocode(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude
                )
                cluster.name = address.name
                cluster.address = address.fullAddress
                cluster.placeType = address.placeType
            } catch {
                cluster.name = "알 수 없는 장소"
                cluster.address = ""
            }

            progress = 0.6 + (0.2 * Double(index + 1) / Double(clusters.count))
        }

        // Step 5: Activity inference
        currentStep = "✨ 활동 유형 분석 중..."
        progress = 0.85

        for cluster in clusters {
            cluster.activityType = activityService.infer(
                placeType: cluster.placeType,
                time: cluster.startTime
            )
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        // Step 6: Build result
        currentStep = "📝 결과 정리 중..."
        progress = 0.95

        let result = buildResult(
            assets: assets,
            gpsPhotos: sortedPhotos,
            clusters: clusters
        )

        progress = 1.0
        currentStep = "완료!"

        return result
    }

    // MARK: - Extract Metadata
    private func extractMetadata(from assets: [PHAsset]) -> [PhotoMetadata] {
        return assets.map { asset in
            PhotoMetadata(
                asset: asset,
                assetId: asset.localIdentifier,
                capturedAt: asset.creationDate,
                latitude: asset.location?.coordinate.latitude,
                longitude: asset.location?.coordinate.longitude
            )
        }
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
