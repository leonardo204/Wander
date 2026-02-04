import SwiftUI
import UIKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareService")

// MARK: - 공유 서비스

/// 여행 기록 공유 기능을 총괄하는 서비스
final class ShareService: ObservableObject {

    // MARK: - Singleton

    static let shared = ShareService()
    private init() {}

    // MARK: - Dependencies

    private let imageGenerator = ShareImageGenerator.shared
    private let instagramService = InstagramShareService.shared

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Public Methods

    /// 일반 공유 (UIActivityViewController)
    @MainActor
    func shareGeneral(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        from viewController: UIViewController
    ) async throws {
        logger.info("📤 [ShareService] 일반 공유 시작")
        isLoading = true

        defer { isLoading = false }

        // 이미지 생성
        let shareImage = try await imageGenerator.generateImage(
            photos: photos,
            data: data,
            configuration: configuration
        )

        // UIActivityViewController 표시
        let activityItems: [Any] = [shareImage]
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // iPad 대응
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
        logger.info("📤 [ShareService] UIActivityViewController 표시됨")
    }

    /// Instagram Feed 공유
    @MainActor
    func shareToInstagramFeed(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration
    ) async throws {
        logger.info("📤 [ShareService] Instagram Feed 공유 시작")
        isLoading = true

        defer { isLoading = false }

        // Feed용 이미지 생성 (4:5 비율)
        var feedConfig = configuration
        feedConfig.destination = .instagramFeed

        let shareImage = try await imageGenerator.generateImage(
            photos: photos,
            data: data,
            configuration: feedConfig
        )

        // Instagram Feed 공유 (캡션은 클립보드로)
        try await instagramService.shareToFeed(
            image: shareImage,
            caption: configuration.clipboardText
        )

        logger.info("📤 [ShareService] Instagram Feed 공유 완료")
    }

    /// Instagram Stories 공유
    @MainActor
    func shareToInstagramStories(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration
    ) async throws {
        logger.info("📤 [ShareService] Instagram Stories 공유 시작")
        isLoading = true

        defer { isLoading = false }

        // Story용 이미지 생성 (9:16 비율)
        let storyImage = imageGenerator.generateStoryImage(
            photos: photos,
            data: data,
            showWatermark: configuration.showWatermark
        )

        // Instagram Stories 공유
        try await instagramService.shareToStories(backgroundImage: storyImage)

        logger.info("📤 [ShareService] Instagram Stories 공유 완료")
    }

    /// Instagram 설치 여부
    var isInstagramInstalled: Bool {
        instagramService.isInstagramInstalled
    }

    /// App Store 열기 (Instagram 설치)
    @MainActor
    func openInstagramAppStore() async {
        await instagramService.openAppStore()
    }

    // MARK: - Photo Loading

    /// PHAsset에서 UIImage 로드
    func loadImages(from assetIdentifiers: [String]) async -> [UIImage] {
        logger.info("📤 [ShareService] 이미지 로드 시작 - \(assetIdentifiers.count)개")

        var images: [UIImage] = []

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)

        // PHFetchResult를 배열로 변환
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        // 병렬로 이미지 로드
        await withTaskGroup(of: UIImage?.self) { group in
            for asset in assets {
                group.addTask {
                    await self.loadImage(from: asset, targetSize: CGSize(width: 1080, height: 1350))
                }
            }

            for await image in group {
                if let image = image {
                    images.append(image)
                }
            }
        }

        logger.info("📤 [ShareService] 이미지 로드 완료 - \(images.count)개")
        return images
    }

    /// 단일 PHAsset에서 UIImage 로드
    private func loadImage(from asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - TravelRecord ShareableData Extension

extension TravelRecord: ShareableData {
    var shareTitle: String {
        title
    }

    var shareDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: endDate))"
    }

    var sharePlaceCount: Int {
        placeCount
    }

    var shareTotalDistance: Double {
        totalDistance
    }

    var sharePhotoAssetIdentifiers: [String] {
        days.flatMap { $0.places.flatMap { $0.photos.compactMap { $0.assetIdentifier } } }
    }

    var shareAIStory: String? {
        aiStory
    }
}

// MARK: - View Extension for Sharing

extension View {
    /// 현재 View를 UIImage로 렌더링
    @MainActor
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view

        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}
