import Foundation
import Photos
import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoAssetManager")

/// 사진 라이브러리에서 PHAsset을 fetch하고 관리하는 클래스
@MainActor
class PhotoAssetManager: ObservableObject {
    // MARK: - Published Properties

    @Published var assets: [PHAsset] = []
    @Published var isLoading = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private let imageManager = PHCachingImageManager()
    private var fetchResult: PHFetchResult<PHAsset>?

    // MARK: - Initialization

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if status == .authorized || status == .limited {
            await fetchAssets(for: .thisMonth)
        }
    }

    // MARK: - Fetch Assets

    /// 날짜 범위에 따라 사진을 fetch
    func fetchAssets(for dateRange: DateFilterRange) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            logger.warning("📷 [PhotoAssetManager] 사진 접근 권한 없음")
            return
        }

        isLoading = true
        logger.info("📷 [PhotoAssetManager] 사진 fetch 시작: \(dateRange.title)")

        let (startDate, endDate) = dateRange.dateRange

        let fetchOptions = PHFetchOptions()

        // 날짜 필터링 predicate
        if let start = startDate {
            if let end = endDate {
                fetchOptions.predicate = NSPredicate(
                    format: "creationDate >= %@ AND creationDate <= %@ AND mediaType == %d",
                    start as NSDate,
                    end as NSDate,
                    PHAssetMediaType.image.rawValue
                )
            } else {
                fetchOptions.predicate = NSPredicate(
                    format: "creationDate >= %@ AND mediaType == %d",
                    start as NSDate,
                    PHAssetMediaType.image.rawValue
                )
            }
        } else {
            // 전체 기간
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )
        }

        // 최신순 정렬
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Fetch 실행
        fetchResult = PHAsset.fetchAssets(with: fetchOptions)

        var fetchedAssets: [PHAsset] = []
        fetchResult?.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }

        assets = fetchedAssets
        isLoading = false

        logger.info("📷 [PhotoAssetManager] 사진 fetch 완료: \(fetchedAssets.count)장")
    }

    // MARK: - Thumbnail Loading

    /// 썸네일 이미지 로드
    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Caching

    func startCaching(assets: [PHAsset], targetSize: CGSize) {
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopCaching(assets: [PHAsset], targetSize: CGSize) {
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopAllCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }
}

// MARK: - Date Filter Range

/// 날짜 필터 범위 정의
enum DateFilterRange: String, CaseIterable, Identifiable {
    case today = "오늘"
    case thisWeek = "이번 주"
    case thisMonth = "이번 달"
    case last3Months = "최근 3개월"
    case all = "전체"

    var id: String { rawValue }
    var title: String { rawValue }

    /// 해당 범위의 시작/종료 날짜 반환
    var dateRange: (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return (startOfDay, now)

        case .thisWeek:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (weekStart, now)

        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (monthStart, now)

        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return (threeMonthsAgo, now)

        case .all:
            return (nil, nil)
        }
    }
}
