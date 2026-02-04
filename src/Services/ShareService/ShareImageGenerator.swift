import SwiftUI
import UIKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ShareImageGenerator")

// MARK: - 공유 이미지 생성기

/// 공유용 이미지를 생성하는 서비스
final class ShareImageGenerator {

    // MARK: - Singleton

    static let shared = ShareImageGenerator()
    private init() {}

    // MARK: - Constants (UX 개선 - 가독성을 위해 텍스트 크기 대폭 증가)

    private struct DesignConstants {
        // 글래스 패널 (캡션/해시태그 포함으로 높이 증가)
        static let glassPanelHeight: CGFloat = 440  // 텍스트 크기 증가로 패널도 확대
        static let glassPanelMargin: CGFloat = 30
        static let glassPanelCornerRadius: CGFloat = 24

        // 타이포그래피 (제목 제외 1.5배 증가)
        static let titleFontSize: CGFloat = 42      // 유지
        static let statsFontSize: CGFloat = 36      // 24 × 1.5 = 36
        static let dateFontSize: CGFloat = 33       // 22 × 1.5 = 33
        static let captionFontSize: CGFloat = 30    // 20 × 1.5 = 30
        static let hashtagFontSize: CGFloat = 27    // 18 × 1.5 = 27
        static let watermarkFontSize: CGFloat = 24  // 16 × 1.5 = 24

        // 워터마크/로고
        static let watermarkIconSize: CGFloat = 36  // 앱 아이콘 크기
        static let watermarkWidth: CGFloat = 140    // 전체 로고 영역

        // 스토리용
        static let storyTitleFontSize: CGFloat = 38
        static let storyStatsFontSize: CGFloat = 36

        // 폴라로이드
        static let polaroidTitleFontSize: CGFloat = 44  // 유지
        static let polaroidDateFontSize: CGFloat = 33   // 22 × 1.5 = 33
        static let polaroidCaptionFontSize: CGFloat = 27
    }

    // MARK: - Public Methods

    /// 공유 이미지 생성 (여러 장 반환 가능)
    func generateImages(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration
    ) async throws -> [UIImage] {
        logger.info("📸 [ShareImageGenerator] 이미지 생성 시작 - 스타일: \(configuration.templateStyle.rawValue), 사진 수: \(photos.count)")

        guard !photos.isEmpty else {
            throw ShareError.noPhotosSelected
        }

        let size = configuration.destination.imageSize

        // 스타일에 따른 렌더링
        let images: [UIImage]

        switch configuration.templateStyle {
        case .modernGlass:
            images = renderModernGlassMultiple(
                photos: photos,
                data: data,
                configuration: configuration,
                size: size
            )
        case .polaroidGrid:
            images = renderPolaroidGridMultiple(
                photos: photos,
                data: data,
                configuration: configuration,
                size: size
            )
        case .cleanMinimal:
            images = renderCleanMinimalMultiple(
                photos: photos,
                data: data,
                configuration: configuration,
                size: size
            )
        }

        logger.info("📸 [ShareImageGenerator] 이미지 생성 완료 - 총 \(images.count)장")

        return images
    }

    /// 단일 이미지 생성 (하위 호환성)
    func generateImage(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration
    ) async throws -> UIImage {
        let images = try await generateImages(photos: photos, data: data, configuration: configuration)
        guard let first = images.first else {
            throw ShareError.imageGenerationFailed
        }
        return first
    }

    /// Instagram Story용 이미지 생성 (9:16)
    func generateStoryImage(
        photos: [UIImage],
        data: ShareableData,
        showWatermark: Bool = true
    ) -> UIImage {
        let size = ShareDestination.instagramStory.imageSize
        return renderStoryTemplate(photos: photos, data: data, size: size, showWatermark: showWatermark)
    }

    // MARK: - Modern Glass Template (Multiple)

    private func renderModernGlassMultiple(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize
    ) -> [UIImage] {
        logger.info("📸 [ModernGlass] 렌더링 시작 - 사진 수: \(photos.count), 크기: \(Int(size.width))x\(Int(size.height))")

        // 각 사진마다 1장씩 이미지 생성
        let results = photos.enumerated().map { index, photo in
            logger.info("📸 [ModernGlass] 사진[\(index)] 렌더링 중 - 원본 크기: \(Int(photo.size.width))x\(Int(photo.size.height))")
            let rendered = renderModernGlassSingle(
                photo: photo,
                data: data,
                configuration: configuration,
                size: size,
                pageIndex: index,
                totalPages: photos.count
            )
            logger.info("📸 [ModernGlass] 사진[\(index)] 렌더링 완료 - 결과 크기: \(Int(rendered.size.width))x\(Int(rendered.size.height))")
            return rendered
        }

        logger.info("📸 [ModernGlass] 렌더링 완료 - 총 \(results.count)장")
        return results
    }

    private func renderModernGlassSingle(
        photo: UIImage,
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize,
        pageIndex: Int,
        totalPages: Int
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 메인 사진 배경 (전체)
            drawImageFill(photo, in: CGRect(origin: .zero, size: size), context: cgContext)

            // 2. 상단 그라데이션 (어두운 → 투명)
            let topGradientHeight: CGFloat = 100
            let topGradientRect = CGRect(x: 0, y: 0, width: size.width, height: topGradientHeight)
            drawGradientOverlay(in: topGradientRect, context: cgContext, direction: .topToBottom)

            // 3. 하단 글래스 패널 (캡션/해시태그 포함으로 확대)
            let panelHeight = DesignConstants.glassPanelHeight
            let panelMargin = DesignConstants.glassPanelMargin
            let panelRect = CGRect(
                x: panelMargin,
                y: size.height - panelHeight - 40,
                width: size.width - (panelMargin * 2),
                height: panelHeight
            )

            drawGlassPanel(in: panelRect, context: cgContext, cornerRadius: DesignConstants.glassPanelCornerRadius)

            // 4. 패널 내 텍스트
            let textMargin: CGFloat = 28
            var currentY = panelRect.minY + textMargin

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.titleFontSize, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let title = data.shareTitle
            title.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: titleAttributes)
            currentY += DesignConstants.titleFontSize + 12

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.dateFontSize, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            data.shareDateRange.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: dateAttributes)
            currentY += DesignConstants.dateFontSize + 14

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.statsFontSize, weight: .medium),
                .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.85) ?? .darkGray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳  ·  🚗 \(Int(data.shareTotalDistance))km"
            stats.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: statsAttributes)
            currentY += DesignConstants.statsFontSize + 18

            // 구분선
            let dividerY = currentY
            cgContext.setStrokeColor(UIColor(hex: "#1A2B33")?.withAlphaComponent(0.15).cgColor ?? UIColor.gray.cgColor)
            cgContext.setLineWidth(2)
            cgContext.move(to: CGPoint(x: panelRect.minX + textMargin, y: dividerY))
            cgContext.addLine(to: CGPoint(x: panelRect.maxX - textMargin, y: dividerY))
            cgContext.strokePath()
            currentY += 16

            // 캡션 (첫 번째 이미지에만 표시하거나, 공간이 있으면 모든 이미지에)
            if !configuration.caption.isEmpty {
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.captionFontSize, weight: .regular),
                    .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.9) ?? .darkGray
                ]

                // 캡션 텍스트 (최대 2줄)
                let maxCaptionWidth = panelRect.width - (textMargin * 2)
                let captionText = truncateText(configuration.caption, maxLines: 2, width: maxCaptionWidth, font: UIFont.systemFont(ofSize: DesignConstants.captionFontSize))

                let captionRect = CGRect(
                    x: panelRect.minX + textMargin,
                    y: currentY,
                    width: maxCaptionWidth,
                    height: 75
                )
                captionText.draw(in: captionRect, withAttributes: captionAttributes)
                currentY += 75
            }

            // 해시태그
            if !configuration.hashtags.isEmpty {
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize, weight: .medium),
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]

                let hashtagText = configuration.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " ")
                let maxHashtagWidth = panelRect.width - (textMargin * 2)
                let truncatedHashtags = truncateText(hashtagText, maxLines: 1, width: maxHashtagWidth, font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize))

                truncatedHashtags.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: hashtagAttributes)
            }

            // 5. 페이지 인디케이터 (여러 장일 때)
            if totalPages > 1 {
                let indicatorText = "\(pageIndex + 1)/\(totalPages)"
                let indicatorAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                let indicatorSize = indicatorText.size(withAttributes: indicatorAttributes)

                let indicatorPadding: CGFloat = 10
                let indicatorRect = CGRect(
                    x: size.width - indicatorSize.width - indicatorPadding * 2 - 16,
                    y: 16,
                    width: indicatorSize.width + indicatorPadding * 2,
                    height: indicatorSize.height + indicatorPadding
                )

                cgContext.saveGState()
                UIColor.black.withAlphaComponent(0.5).setFill()
                let indicatorPath = UIBezierPath(roundedRect: indicatorRect, cornerRadius: indicatorRect.height / 2)
                indicatorPath.fill()
                cgContext.restoreGState()

                indicatorText.draw(
                    at: CGPoint(x: indicatorRect.minX + indicatorPadding, y: indicatorRect.minY + indicatorPadding / 2),
                    withAttributes: indicatorAttributes
                )
            }

            // 6. 워터마크 (앱 아이콘 + Wander)
            if configuration.showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: panelRect.maxX - DesignConstants.watermarkWidth - 16,
                        y: panelRect.maxY - 50,
                        width: DesignConstants.watermarkWidth,
                        height: DesignConstants.watermarkIconSize
                    ),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Polaroid Grid Template (Multiple)

    private func renderPolaroidGridMultiple(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize
    ) -> [UIImage] {
        // 한 이미지에 최대 3장, 그 이상은 추가 페이지
        let photosPerPage = 3
        var images: [UIImage] = []

        let chunks = stride(from: 0, to: photos.count, by: photosPerPage).map {
            Array(photos[$0..<min($0 + photosPerPage, photos.count)])
        }

        for (pageIndex, chunk) in chunks.enumerated() {
            let image = renderPolaroidGridPage(
                photos: chunk,
                data: data,
                configuration: configuration,
                size: size,
                pageIndex: pageIndex,
                totalPages: chunks.count
            )
            images.append(image)
        }

        return images
    }

    private func renderPolaroidGridPage(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize,
        pageIndex: Int,
        totalPages: Int
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 배경 (연한 베이지/크림)
            UIColor(hex: "#FAF8F5")?.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 폴라로이드 그리드 (최대 3장)
            let polaroidPhotos = photos
            let photoCount = polaroidPhotos.count

            // 사진 개수에 따른 레이아웃 조정 (해상도 축소에 맞춰 크기 조정)
            let polaroidSize: CGSize
            let positions: [CGPoint]
            let rotations: [CGFloat]

            switch photoCount {
            case 1:
                polaroidSize = CGSize(width: 380, height: 450)
                positions = [CGPoint(x: (size.width - polaroidSize.width) / 2, y: 80)]
                rotations = [-2]
            case 2:
                polaroidSize = CGSize(width: 300, height: 360)
                positions = [
                    CGPoint(x: 60, y: 90),
                    CGPoint(x: size.width - 360, y: 120)
                ]
                rotations = [-5, 4]
            default: // 3
                polaroidSize = CGSize(width: 220, height: 270)
                positions = [
                    CGPoint(x: 40, y: 80),
                    CGPoint(x: (size.width - polaroidSize.width) / 2, y: 110),
                    CGPoint(x: size.width - polaroidSize.width - 40, y: 80)
                ]
                rotations = [-6, 2, -3]
            }

            for (index, photo) in polaroidPhotos.enumerated() {
                let rotation = rotations[index % rotations.count] * .pi / 180
                let position = positions[index % positions.count]

                cgContext.saveGState()

                // 회전 중심점
                let centerX = position.x + polaroidSize.width / 2
                let centerY = position.y + polaroidSize.height / 2
                cgContext.translateBy(x: centerX, y: centerY)
                cgContext.rotate(by: rotation)
                cgContext.translateBy(x: -centerX, y: -centerY)

                // 폴라로이드 프레임 (흰색 + 그림자)
                let frameRect = CGRect(origin: position, size: polaroidSize)

                cgContext.setShadow(offset: CGSize(width: 0, height: 5), blur: 12, color: UIColor.black.withAlphaComponent(0.18).cgColor)
                UIColor.white.setFill()
                cgContext.fill(frameRect)
                cgContext.setShadow(offset: .zero, blur: 0)

                // 사진 영역 (프레임 안쪽)
                let photoMargin: CGFloat = 15
                let photoRect = CGRect(
                    x: position.x + photoMargin,
                    y: position.y + photoMargin,
                    width: polaroidSize.width - photoMargin * 2,
                    height: polaroidSize.height - photoMargin * 2 - 30
                )
                drawImageFill(photo, in: photoRect, context: cgContext)

                cgContext.restoreGState()
            }

            // 3. 하단 정보
            let lastPolaroidBottom = positions.last!.y + polaroidSize.height
            let infoY = max(lastPolaroidBottom + 40, size.height - 240)

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Noteworthy-Bold", size: DesignConstants.polaroidTitleFontSize) ?? UIFont.systemFont(ofSize: DesignConstants.polaroidTitleFontSize, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let titleSize = data.shareTitle.size(withAttributes: titleAttributes)
            data.shareTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: infoY),
                withAttributes: titleAttributes
            )

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.polaroidDateFontSize, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            let dateSize = data.shareDateRange.size(withAttributes: dateAttributes)
            data.shareDateRange.draw(
                at: CGPoint(x: (size.width - dateSize.width) / 2, y: infoY + 40),
                withAttributes: dateAttributes
            )

            // 캡션 (짧게)
            var currentInfoY = infoY + 65
            if !configuration.caption.isEmpty {
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.polaroidCaptionFontSize, weight: .regular),
                    .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
                ]
                let maxWidth = size.width - 80
                let captionText = truncateText(configuration.caption, maxLines: 2, width: maxWidth, font: UIFont.systemFont(ofSize: DesignConstants.polaroidCaptionFontSize))
                let captionSize = captionText.size(withAttributes: captionAttributes)
                captionText.draw(
                    at: CGPoint(x: (size.width - min(captionSize.width, maxWidth)) / 2, y: currentInfoY),
                    withAttributes: captionAttributes
                )
                currentInfoY += 35
            }

            // 해시태그
            if !configuration.hashtags.isEmpty {
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize, weight: .medium),
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]
                let hashtagText = configuration.hashtags.prefix(4).map { "#\($0)" }.joined(separator: " ")
                let hashtagSize = hashtagText.size(withAttributes: hashtagAttributes)
                hashtagText.draw(
                    at: CGPoint(x: (size.width - hashtagSize.width) / 2, y: currentInfoY),
                    withAttributes: hashtagAttributes
                )
            }

            // 4. 페이지 인디케이터 (여러 장일 때)
            if totalPages > 1 {
                let indicatorText = "\(pageIndex + 1)/\(totalPages)"
                let indicatorAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
                ]
                let indicatorSize = indicatorText.size(withAttributes: indicatorAttributes)
                indicatorText.draw(
                    at: CGPoint(x: (size.width - indicatorSize.width) / 2, y: size.height - 50),
                    withAttributes: indicatorAttributes
                )
            }

            // 5. 워터마크 (앱 아이콘 + Wander)
            if configuration.showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: size.width - DesignConstants.watermarkWidth - 20,
                        y: size.height - 55,
                        width: DesignConstants.watermarkWidth,
                        height: DesignConstants.watermarkIconSize
                    ),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Clean Minimal Template (Multiple)

    private func renderCleanMinimalMultiple(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize
    ) -> [UIImage] {
        // 한 이미지에 최대 4장 (2x2 그리드), 그 이상은 추가 페이지
        let photosPerPage = 4
        var images: [UIImage] = []

        let chunks = stride(from: 0, to: photos.count, by: photosPerPage).map {
            Array(photos[$0..<min($0 + photosPerPage, photos.count)])
        }

        for (pageIndex, chunk) in chunks.enumerated() {
            let image = renderCleanMinimalPage(
                photos: chunk,
                data: data,
                configuration: configuration,
                size: size,
                pageIndex: pageIndex,
                totalPages: chunks.count
            )
            images.append(image)
        }

        return images
    }

    private func renderCleanMinimalPage(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration,
        size: CGSize,
        pageIndex: Int,
        totalPages: Int
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 배경 (화이트)
            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 사진 그리드 (개수에 따라 레이아웃 변경)
            let photoMargin: CGFloat = 36
            let photoSpacing: CGFloat = 12
            let cornerRadius: CGFloat = 16
            let availableWidth = size.width - (photoMargin * 2)
            let photoAreaTop: CGFloat = 40

            switch photos.count {
            case 1:
                // 1장: 전체 크기
                let photoHeight: CGFloat = size.height * 0.50
                let photoRect = CGRect(
                    x: photoMargin,
                    y: photoAreaTop,
                    width: availableWidth,
                    height: photoHeight
                )
                drawRoundedImage(photos[0], in: photoRect, cornerRadius: cornerRadius, context: cgContext)

            case 2:
                // 2장: 세로 2분할
                let photoHeight = (size.height * 0.50 - photoSpacing) / 2
                for (index, photo) in photos.enumerated() {
                    let photoRect = CGRect(
                        x: photoMargin,
                        y: photoAreaTop + CGFloat(index) * (photoHeight + photoSpacing),
                        width: availableWidth,
                        height: photoHeight
                    )
                    drawRoundedImage(photo, in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                }

            case 3:
                // 3장: 상단 1장 크게 + 하단 2장 작게
                let topPhotoHeight = size.height * 0.32
                let bottomPhotoHeight = size.height * 0.16
                let halfWidth = (availableWidth - photoSpacing) / 2

                let topRect = CGRect(x: photoMargin, y: photoAreaTop, width: availableWidth, height: topPhotoHeight)
                drawRoundedImage(photos[0], in: topRect, cornerRadius: cornerRadius, context: cgContext)

                for (index, photo) in photos.dropFirst().enumerated() {
                    let photoRect = CGRect(
                        x: photoMargin + CGFloat(index) * (halfWidth + photoSpacing),
                        y: photoAreaTop + topPhotoHeight + photoSpacing,
                        width: halfWidth,
                        height: bottomPhotoHeight
                    )
                    drawRoundedImage(photo, in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                }

            default: // 4장
                // 4장: 2x2 그리드
                let photoSize = (availableWidth - photoSpacing) / 2
                let photoHeight = (size.height * 0.48 - photoSpacing) / 2

                for (index, photo) in photos.enumerated() {
                    let row = index / 2
                    let col = index % 2
                    let photoRect = CGRect(
                        x: photoMargin + CGFloat(col) * (photoSize + photoSpacing),
                        y: photoAreaTop + CGFloat(row) * (photoHeight + photoSpacing),
                        width: photoSize,
                        height: photoHeight
                    )
                    drawRoundedImage(photo, in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                }
            }

            // 3. 하단 정보 (센터 정렬)
            let infoY = size.height * 0.58

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.titleFontSize, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let titleSize = data.shareTitle.size(withAttributes: titleAttributes)
            data.shareTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: infoY),
                withAttributes: titleAttributes
            )

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.dateFontSize, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            let dateSize = data.shareDateRange.size(withAttributes: dateAttributes)
            data.shareDateRange.draw(
                at: CGPoint(x: (size.width - dateSize.width) / 2, y: infoY + 35),
                withAttributes: dateAttributes
            )

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.statsFontSize, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳  ·  🚗 \(Int(data.shareTotalDistance))km"
            let statsSize = stats.size(withAttributes: statsAttributes)
            stats.draw(
                at: CGPoint(x: (size.width - statsSize.width) / 2, y: infoY + 58),
                withAttributes: statsAttributes
            )

            // 캡션
            var currentInfoY: CGFloat = infoY + 85
            if !configuration.caption.isEmpty {
                let captionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.captionFontSize, weight: .regular),
                    .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.8) ?? .darkGray
                ]
                let maxWidth = size.width - 60
                let captionText = truncateText(configuration.caption, maxLines: 2, width: maxWidth, font: UIFont.systemFont(ofSize: DesignConstants.captionFontSize))
                let captionSize = captionText.size(withAttributes: captionAttributes)
                captionText.draw(
                    at: CGPoint(x: (size.width - min(captionSize.width, maxWidth)) / 2, y: currentInfoY),
                    withAttributes: captionAttributes
                )
                currentInfoY += 40
            }

            // 해시태그
            if !configuration.hashtags.isEmpty {
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize, weight: .medium),
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]
                let hashtagText = configuration.hashtags.prefix(5).map { "#\($0)" }.joined(separator: " ")
                let hashtagSize = hashtagText.size(withAttributes: hashtagAttributes)
                hashtagText.draw(
                    at: CGPoint(x: (size.width - hashtagSize.width) / 2, y: currentInfoY),
                    withAttributes: hashtagAttributes
                )
            }

            // 4. 페이지 인디케이터 (여러 장일 때)
            if totalPages > 1 {
                let indicatorText = "\(pageIndex + 1)/\(totalPages)"
                let indicatorAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
                ]
                let indicatorSize = indicatorText.size(withAttributes: indicatorAttributes)
                indicatorText.draw(
                    at: CGPoint(x: (size.width - indicatorSize.width) / 2, y: size.height - 50),
                    withAttributes: indicatorAttributes
                )
            }

            // 5. 워터마크 (앱 아이콘 + Wander)
            if configuration.showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: (size.width - DesignConstants.watermarkWidth) / 2,
                        y: size.height - 60,
                        width: DesignConstants.watermarkWidth,
                        height: DesignConstants.watermarkIconSize
                    ),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Story Template (9:16)

    private func renderStoryTemplate(
        photos: [UIImage],
        data: ShareableData,
        size: CGSize,
        showWatermark: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 전체 배경 사진
            if let mainPhoto = photos.first {
                drawImageFill(mainPhoto, in: CGRect(origin: .zero, size: size), context: cgContext)
            }

            // 2. 글래스 스티커 (하단)
            let stickerHeight: CGFloat = 140
            let stickerMargin: CGFloat = 40
            let stickerRect = CGRect(
                x: stickerMargin,
                y: size.height - stickerHeight - 140,
                width: size.width - (stickerMargin * 2),
                height: stickerHeight
            )

            drawGlassPanel(in: stickerRect, context: cgContext, cornerRadius: 18)

            // 3. 스티커 내 텍스트
            let textMargin: CGFloat = 20
            var currentY = stickerRect.minY + textMargin

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.storyTitleFontSize, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            data.shareTitle.draw(
                at: CGPoint(x: stickerRect.minX + textMargin, y: currentY),
                withAttributes: titleAttributes
            )
            currentY += DesignConstants.storyTitleFontSize + 8

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            data.shareDateRange.draw(
                at: CGPoint(x: stickerRect.minX + textMargin, y: currentY),
                withAttributes: dateAttributes
            )
            currentY += 22

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.storyStatsFontSize, weight: .medium),
                .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.85) ?? .darkGray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳 방문  ·  🚗 \(Int(data.shareTotalDistance))km"
            stats.draw(
                at: CGPoint(x: stickerRect.minX + textMargin, y: currentY),
                withAttributes: statsAttributes
            )

            // 워터마크 (앱 아이콘 + Wander)
            if showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: size.width - DesignConstants.watermarkWidth - 24,
                        y: size.height - 80,
                        width: DesignConstants.watermarkWidth,
                        height: DesignConstants.watermarkIconSize
                    ),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Helper Methods

    /// 이미지를 영역에 맞게 채우기 (Aspect Fill)
    private func drawImageFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        let targetSize = rect.size

        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = max(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let drawRect = CGRect(
            x: rect.minX + (targetSize.width - scaledWidth) / 2,
            y: rect.minY + (targetSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )

        context.saveGState()
        context.addRect(rect)
        context.clip()
        image.draw(in: drawRect)
        context.restoreGState()
    }

    /// 둥근 모서리 이미지 그리기
    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        path.addClip()
        drawImageFill(image, in: rect, context: context)
        context.restoreGState()
    }

    /// 글래스 패널 그리기
    private func drawGlassPanel(in rect: CGRect, context: CGContext, cornerRadius: CGFloat = 20) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        // 그림자
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 5), blur: 14, color: UIColor.black.withAlphaComponent(0.12).cgColor)
        UIColor.white.withAlphaComponent(0.85).setFill()
        path.fill()
        context.restoreGState()
    }

    /// 그라데이션 오버레이 그리기
    private func drawGradientOverlay(in rect: CGRect, context: CGContext, direction: GradientDirection) {
        let colors = [UIColor.black.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }

        context.saveGState()
        context.addRect(rect)
        context.clip()

        let startPoint: CGPoint
        let endPoint: CGPoint

        switch direction {
        case .topToBottom:
            startPoint = CGPoint(x: rect.midX, y: rect.minY)
            endPoint = CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomToTop:
            startPoint = CGPoint(x: rect.midX, y: rect.maxY)
            endPoint = CGPoint(x: rect.midX, y: rect.minY)
        }

        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        context.restoreGState()
    }

    private enum GradientDirection {
        case topToBottom
        case bottomToTop
    }

    /// 워터마크 그리기 (앱 아이콘 + 텍스트)
    private func drawWatermark(in rect: CGRect, context: CGContext) {
        let iconSize = DesignConstants.watermarkIconSize
        let spacing: CGFloat = 8

        // 1. 앱 아이콘 그리기
        if let appIcon = UIImage(named: "AppIcon") {
            let iconRect = CGRect(
                x: rect.minX,
                y: rect.minY + (rect.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            // 둥근 모서리로 앱 아이콘 그리기
            let iconPath = UIBezierPath(roundedRect: iconRect, cornerRadius: iconSize * 0.22)
            context.saveGState()
            iconPath.addClip()
            appIcon.draw(in: iconRect)
            context.restoreGState()
        }

        // 2. "Wander" 텍스트 그리기
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: DesignConstants.watermarkFontSize, weight: .semibold),
            .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
        ]
        let watermarkText = "Wander"
        let textX = rect.minX + iconSize + spacing
        let textSize = watermarkText.size(withAttributes: watermarkAttributes)
        let textY = rect.minY + (rect.height - textSize.height) / 2
        watermarkText.draw(at: CGPoint(x: textX, y: textY), withAttributes: watermarkAttributes)
    }

    /// 텍스트 자르기 (최대 줄 수 제한)
    private func truncateText(_ text: String, maxLines: Int, width: CGFloat, font: UIFont) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        var result = ""
        var currentLine = ""
        var lineCount = 0

        for word in words {
            let testLine = currentLine.isEmpty ? word : currentLine + " " + word
            let testSize = testLine.size(withAttributes: [.font: font])

            if testSize.width > width {
                if !currentLine.isEmpty {
                    lineCount += 1
                    if lineCount >= maxLines {
                        result += currentLine + "..."
                        return result
                    }
                    result += currentLine + "\n"
                    currentLine = word
                } else {
                    // 단어 자체가 너무 길면 자르기
                    currentLine = String(word.prefix(Int(width / 8)))
                }
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            result += currentLine
        }

        return result
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
