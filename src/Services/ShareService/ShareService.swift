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

    /// 일반 공유 (UIActivityViewController) - 여러 이미지 지원
    /// - Returns: 공유 완료 여부 (true: 공유 성공, false: 취소)
    @MainActor
    func shareGeneral(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        from viewController: UIViewController
    ) async throws -> Bool {
        logger.info("📤 [ShareService] 일반 공유 시작")
        isLoading = true

        defer { isLoading = false }

        // 여러 이미지 생성
        let shareImages = try await imageGenerator.generateImages(
            photos: photos,
            data: data,
            configuration: configuration
        )

        logger.info("📤 [ShareService] 공유할 이미지 \(shareImages.count)장 생성됨")

        // 이미지를 임시 파일로 저장 (메모리 효율성)
        let tempURLs = try await saveImagesToTempFiles(shareImages)
        logger.info("📤 [ShareService] 이미지를 임시 파일로 저장 완료 - \(tempURLs.count)개 파일")

        // 최상위 presented view controller 찾기 (Sheet 위에서 표시하기 위해)
        let presentingVC = findTopmostViewController(from: viewController)

        // UIActivityViewController 표시 및 완료 대기
        return await withCheckedContinuation { continuation in
            // URL을 activityItems에 추가 (메모리 효율적)
            let activityItems: [Any] = tempURLs
            let activityVC = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )

            // 완료 핸들러 - 공유 완료 또는 취소 시 호출
            activityVC.completionWithItemsHandler = { [tempURLs] activityType, completed, _, error in
                // 공유 완료 후 임시 파일 삭제
                self.cleanupTempFiles(tempURLs)

                if let error = error {
                    logger.error("📤 [ShareService] 공유 에러: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                } else if completed {
                    logger.info("📤 [ShareService] 공유 완료: \(activityType?.rawValue ?? "unknown") - \(tempURLs.count)장")
                    continuation.resume(returning: true)
                } else {
                    logger.info("📤 [ShareService] 공유 취소됨")
                    continuation.resume(returning: false)
                }
            }

            // iPad 대응
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = presentingVC.view
                popoverController.sourceRect = CGRect(
                    x: presentingVC.view.bounds.midX,
                    y: presentingVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popoverController.permittedArrowDirections = []
            }

            // 이미 다른 것을 presenting 중인지 확인
            if presentingVC.presentedViewController != nil {
                logger.warning("📤 [ShareService] 이미 다른 뷰를 표시 중 - 공유 취소")
                self.cleanupTempFiles(tempURLs)
                continuation.resume(returning: false)
                return
            }

            presentingVC.present(activityVC, animated: true)
            logger.info("📤 [ShareService] UIActivityViewController 표시됨 - \(tempURLs.count)장 이미지 (파일)")
        }
    }

    /// 이미지를 임시 파일로 저장
    private func saveImagesToTempFiles(_ images: [UIImage]) async throws -> [URL] {
        var urls: [URL] = []
        let tempDir = FileManager.default.temporaryDirectory

        for (index, image) in images.enumerated() {
            let fileName = "wander_share_\(index)_\(Date().timeIntervalSince1970).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)

            // JPEG 압축 (품질 70% - 공유용으로 충분)
            guard let imageData = image.jpegData(compressionQuality: 0.70) else {
                logger.error("📤 [ShareService] 이미지 변환 실패: \(index)")
                continue
            }

            try imageData.write(to: fileURL)
            urls.append(fileURL)
            logger.info("📤 [ShareService] 임시 파일 저장: \(fileName) (\(imageData.count / 1024)KB)")
        }

        return urls
    }

    /// 임시 파일 삭제
    private func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
                logger.info("📤 [ShareService] 임시 파일 삭제: \(url.lastPathComponent)")
            } catch {
                logger.warning("📤 [ShareService] 임시 파일 삭제 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 최상위 presented view controller 찾기
    private func findTopmostViewController(from viewController: UIViewController) -> UIViewController {
        var topVC = viewController
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }

    /// Instagram Feed 공유 (여러 이미지 지원)
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

        let shareImages = try await imageGenerator.generateImages(
            photos: photos,
            data: data,
            configuration: feedConfig
        )

        // Instagram Feed 공유 - 첫 번째 이미지만 (Instagram API 제한)
        // 여러 장일 경우 사용자가 수동으로 추가해야 함
        guard let firstImage = shareImages.first else {
            throw ShareError.imageGenerationFailed
        }

        try await instagramService.shareToFeed(
            image: firstImage,
            caption: configuration.clipboardText
        )

        logger.info("📤 [ShareService] Instagram Feed 공유 완료 - \(shareImages.count)장 중 1장")
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
