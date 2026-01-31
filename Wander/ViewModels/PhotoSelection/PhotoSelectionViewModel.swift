import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoSelectionVM")

enum QuickSelectRange {
    case today
    case thisWeek
    case thisMonth
    case last3Months
    case all
    case custom
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

    // MARK: - Computed Properties
    var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
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
    var places: [PlaceCluster] = []
    var totalDistance: Double = 0
    var photoCount: Int = 0

    var placeCount: Int {
        places.count
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

    init(latitude: Double, longitude: Double, startTime: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.startTime = startTime
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        case .other: return WanderColors.surface
        }
    }
}

import CoreLocation
