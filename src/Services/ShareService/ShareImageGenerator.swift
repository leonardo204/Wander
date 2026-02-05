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

    // MARK: - Constants (v2.0 - 날짜 통합, 감성 키워드 추가)

    private struct DesignConstants {
        // 글래스 패널 (날짜 줄 제거로 높이 축소)
        static let glassPanelHeight: CGFloat = 340
        static let glassPanelMargin: CGFloat = 30
        static let glassPanelCornerRadius: CGFloat = 24

        // 타이포그래피 (스펙 문서 기준)
        static let titleFontSize: CGFloat = 42       // 제목
        static let statsFontSize: CGFloat = 30       // 통계+날짜 통합
        static let impressionFontSize: CGFloat = 28  // 감성 키워드 (캡션 대체)
        static let hashtagFontSize: CGFloat = 24     // 해시태그
        static let watermarkFontSize: CGFloat = 22   // 워터마크 텍스트

        // 워터마크/로고
        static let watermarkIconSize: CGFloat = 36   // 앱 아이콘 크기
        static let watermarkTextSize: CGFloat = 22   // Wander 텍스트 크기
        static let watermarkWidth: CGFloat = 150     // 전체 로고 영역

        // 폴라로이드
        static let polaroidTitleFontSize: CGFloat = 42
        static let polaroidStatsFontSize: CGFloat = 28
        static let polaroidImpressionFontSize: CGFloat = 26
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

            // 4. 패널 내 텍스트 (v2.0 - 날짜 통합, 감성 키워드)
            let textMargin: CGFloat = 28
            var currentY = panelRect.minY + textMargin
            let maxTextWidth = panelRect.width - (textMargin * 2)

            // 제목 (최대 15자, 초과 시 말줄임)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.titleFontSize, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let title = truncateText(data.shareTitle, maxLines: 1, width: maxTextWidth, font: UIFont.systemFont(ofSize: DesignConstants.titleFontSize, weight: .bold))
            title.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: titleAttributes)
            currentY += DesignConstants.titleFontSize + 14

            // 통계+날짜 통합 (📍 5곳 · 🚗 32km · 2.1~2.3)
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: DesignConstants.statsFontSize, weight: .medium),
                .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.85) ?? .darkGray
            ]
            let statsWithDate = data.shareStatsWithDate
            statsWithDate.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: statsAttributes)
            currentY += DesignConstants.statsFontSize + 18

            // 구분선
            let dividerY = currentY
            cgContext.setStrokeColor(UIColor(hex: "#1A2B33")?.withAlphaComponent(0.12).cgColor ?? UIColor.gray.cgColor)
            cgContext.setLineWidth(1.5)
            cgContext.move(to: CGPoint(x: panelRect.minX + textMargin, y: dividerY))
            cgContext.addLine(to: CGPoint(x: panelRect.maxX - textMargin, y: dividerY))
            cgContext.strokePath()
            currentY += 18

            // 감성 키워드 (로맨틱 · 힐링 · 도심탈출)
            if !configuration.impression.isEmpty {
                let impressionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.impressionFontSize, weight: .regular),
                    .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.9) ?? .darkGray
                ]
                let impressionText = truncateText(configuration.impression, maxLines: 1, width: maxTextWidth, font: UIFont.systemFont(ofSize: DesignConstants.impressionFontSize))
                impressionText.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: impressionAttributes)
                currentY += DesignConstants.impressionFontSize + 14
            }

            // 해시태그 (최대 3개)
            if !configuration.hashtags.isEmpty {
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize, weight: .medium),
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]

                let hashtagText = configuration.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " ")
                let truncatedHashtags = truncateText(hashtagText, maxLines: 1, width: maxTextWidth, font: UIFont.systemFont(ofSize: DesignConstants.hashtagFontSize))

                truncatedHashtags.draw(at: CGPoint(x: panelRect.minX + textMargin, y: currentY), withAttributes: hashtagAttributes)
            }

            // 5. 워터마크 (앱 아이콘 + Wander)
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

            // ===== 프로페셔널 폴라로이드 레이아웃 (v3.0) =====

            // 1. 배경 (따뜻한 크림색)
            UIColor(hex: "#F8F6F3")?.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 레이아웃 상수
            let horizontalMargin: CGFloat = 40
            let topMargin: CGFloat = 50
            let bottomMargin: CGFloat = 50
            let textAreaHeight: CGFloat = 140
            let photoToTextGap: CGFloat = 30

            // 사진 영역 계산
            let photoAreaHeight = size.height - topMargin - photoToTextGap - textAreaHeight - bottomMargin

            // 3. 폴라로이드 렌더링 (개수에 따라 레이아웃 최적화)
            let photoCount = photos.count
            let polaroidSize: CGSize
            let positions: [CGPoint]
            let rotations: [CGFloat]

            switch photoCount {
            case 1:
                // 1장: 중앙에 크게 (캔버스의 65% 활용)
                let maxWidth = size.width * 0.65
                let maxHeight = photoAreaHeight * 0.95
                polaroidSize = CGSize(width: maxWidth, height: min(maxWidth * 1.15, maxHeight))
                let centerX = (size.width - polaroidSize.width) / 2
                let centerY = topMargin + (photoAreaHeight - polaroidSize.height) / 2
                positions = [CGPoint(x: centerX, y: centerY)]
                rotations = [-2.5]

            case 2:
                // 2장: 살짝 겹쳐서 다이나믹하게
                let maxWidth = size.width * 0.48
                let maxHeight = photoAreaHeight * 0.90
                polaroidSize = CGSize(width: maxWidth, height: min(maxWidth * 1.15, maxHeight))
                let baseY = topMargin + (photoAreaHeight - polaroidSize.height) / 2
                positions = [
                    CGPoint(x: horizontalMargin + 20, y: baseY - 15),
                    CGPoint(x: size.width - polaroidSize.width - horizontalMargin - 20, y: baseY + 25)
                ]
                rotations = [-6, 5]

            default: // 3장
                // 3장: 부채꼴 배치
                let maxWidth = size.width * 0.36
                let maxHeight = photoAreaHeight * 0.85
                polaroidSize = CGSize(width: maxWidth, height: min(maxWidth * 1.15, maxHeight))
                let baseY = topMargin + (photoAreaHeight - polaroidSize.height) / 2
                let spacing = (size.width - polaroidSize.width * 3) / 4
                positions = [
                    CGPoint(x: spacing, y: baseY + 20),
                    CGPoint(x: spacing * 2 + polaroidSize.width, y: baseY - 10),
                    CGPoint(x: spacing * 3 + polaroidSize.width * 2, y: baseY + 15)
                ]
                rotations = [-5, 0, 4]
            }

            var maxPolaroidBottom: CGFloat = 0

            for (index, photo) in photos.enumerated() {
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

                cgContext.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: UIColor.black.withAlphaComponent(0.15).cgColor)
                UIColor.white.setFill()
                cgContext.fill(frameRect)
                cgContext.setShadow(offset: .zero, blur: 0)

                // 사진 영역 (폴라로이드 스타일: 상단/좌우 얇게, 하단 넓게)
                let photoMarginSide: CGFloat = 14
                let photoMarginTop: CGFloat = 14
                let photoMarginBottom: CGFloat = 50  // 폴라로이드 하단 여백
                let photoRect = CGRect(
                    x: position.x + photoMarginSide,
                    y: position.y + photoMarginTop,
                    width: polaroidSize.width - photoMarginSide * 2,
                    height: polaroidSize.height - photoMarginTop - photoMarginBottom
                )
                drawImageFill(photo, in: photoRect, context: cgContext)

                cgContext.restoreGState()

                maxPolaroidBottom = max(maxPolaroidBottom, position.y + polaroidSize.height)
            }

            // 4. 하단 정보 영역 (컴팩트)
            let textStartY = maxPolaroidBottom + photoToTextGap
            let maxTextWidth = size.width - (horizontalMargin * 2)

            // 제목 (Rounded 폰트)
            let titleFontSize: CGFloat = 36
            let titleFont: UIFont
            if let descriptor = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
                .fontDescriptor.withDesign(.rounded) {
                titleFont = UIFont(descriptor: descriptor, size: titleFontSize)
            } else {
                titleFont = UIFont.systemFont(ofSize: titleFontSize, weight: .bold)
            }

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(hex: "#2C3E50") ?? .black
            ]
            let truncatedTitle = truncateText(data.shareTitle, maxLines: 1, width: maxTextWidth, font: titleFont)
            let titleSize = truncatedTitle.size(withAttributes: titleAttributes)
            truncatedTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: textStartY),
                withAttributes: titleAttributes
            )

            // 통계+날짜
            var currentY = textStartY + titleFontSize + 8
            let statsFont = UIFont.systemFont(ofSize: 24, weight: .medium)
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: statsFont,
                .foregroundColor: UIColor(hex: "#7F8C8D") ?? .gray
            ]
            let statsText = data.shareStatsWithDate
            let statsSize = statsText.size(withAttributes: statsAttributes)
            statsText.draw(
                at: CGPoint(x: (size.width - statsSize.width) / 2, y: currentY),
                withAttributes: statsAttributes
            )
            currentY += 24 + 8

            // 감성 키워드
            if !configuration.impression.isEmpty {
                let impressionFont = UIFont.systemFont(ofSize: 22, weight: .regular)
                let impressionAttributes: [NSAttributedString.Key: Any] = [
                    .font: impressionFont,
                    .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
                ]
                let impressionText = truncateText(configuration.impression, maxLines: 1, width: maxTextWidth, font: impressionFont)
                let impressionSize = impressionText.size(withAttributes: impressionAttributes)
                impressionText.draw(
                    at: CGPoint(x: (size.width - impressionSize.width) / 2, y: currentY),
                    withAttributes: impressionAttributes
                )
                currentY += 22 + 6
            }

            // 해시태그
            if !configuration.hashtags.isEmpty {
                let hashtagFont = UIFont.systemFont(ofSize: 20, weight: .medium)
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: hashtagFont,
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]
                let hashtagText = configuration.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " ")
                let hashtagSize = hashtagText.size(withAttributes: hashtagAttributes)
                hashtagText.draw(
                    at: CGPoint(x: (size.width - hashtagSize.width) / 2, y: currentY),
                    withAttributes: hashtagAttributes
                )
            }

            // 5. 워터마크
            if configuration.showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: size.width - DesignConstants.watermarkWidth - horizontalMargin,
                        y: size.height - bottomMargin - DesignConstants.watermarkIconSize,
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

            // ===== 프로페셔널 레이아웃 (v3.0) =====
            // 캔버스: 1080 x 1350 (4:5)
            // 구성: 상단 마진 → 사진 영역 (70%) → 텍스트 영역 → 하단 마진

            // 1. 배경 (소프트 화이트)
            UIColor(hex: "#FAFAFA")?.setFill() ?? UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 레이아웃 상수 정의
            let horizontalMargin: CGFloat = 40       // 좌우 마진
            let topMargin: CGFloat = 40              // 상단 마진
            let bottomMargin: CGFloat = 50          // 하단 마진
            let photoSpacing: CGFloat = 10           // 사진 간격
            let cornerRadius: CGFloat = 12           // 사진 모서리

            // 텍스트 영역 높이 (컴팩트하게)
            let textAreaHeight: CGFloat = 160
            let photoToTextGap: CGFloat = 24         // 사진과 텍스트 사이 간격

            // 사진 영역 계산
            let availableWidth = size.width - (horizontalMargin * 2)
            let photoAreaTop = topMargin
            let photoAreaHeight = size.height - topMargin - photoToTextGap - textAreaHeight - bottomMargin
            var photoAreaBottom: CGFloat = 0

            // 3. 사진 그리드 렌더링 (사진 개수별 최적화)
            switch photos.count {
            case 1:
                // 1장: 꽉 차게 배치
                let photoRect = CGRect(
                    x: horizontalMargin,
                    y: photoAreaTop,
                    width: availableWidth,
                    height: photoAreaHeight
                )
                let drawnRect = drawRoundedImageFill(photos[0], in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                photoAreaBottom = drawnRect.maxY

            case 2:
                // 2장: 좌우 배치 (가로형) 또는 상하 배치 (세로형)
                let cellWidth = (availableWidth - photoSpacing) / 2
                let cellHeight = photoAreaHeight

                for (index, photo) in photos.enumerated() {
                    let photoRect = CGRect(
                        x: horizontalMargin + CGFloat(index) * (cellWidth + photoSpacing),
                        y: photoAreaTop,
                        width: cellWidth,
                        height: cellHeight
                    )
                    let drawnRect = drawRoundedImageFill(photo, in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                    photoAreaBottom = max(photoAreaBottom, drawnRect.maxY)
                }

            case 3:
                // 3장: 좌측 1장 크게 + 우측 2장 세로 배치
                let leftWidth = availableWidth * 0.55
                let rightWidth = availableWidth - leftWidth - photoSpacing
                let rightCellHeight = (photoAreaHeight - photoSpacing) / 2

                // 좌측 큰 사진
                let leftRect = CGRect(
                    x: horizontalMargin,
                    y: photoAreaTop,
                    width: leftWidth,
                    height: photoAreaHeight
                )
                let leftDrawn = drawRoundedImageFill(photos[0], in: leftRect, cornerRadius: cornerRadius, context: cgContext)
                photoAreaBottom = leftDrawn.maxY

                // 우측 상단
                let rightTopRect = CGRect(
                    x: horizontalMargin + leftWidth + photoSpacing,
                    y: photoAreaTop,
                    width: rightWidth,
                    height: rightCellHeight
                )
                _ = drawRoundedImageFill(photos[1], in: rightTopRect, cornerRadius: cornerRadius, context: cgContext)

                // 우측 하단
                let rightBottomRect = CGRect(
                    x: horizontalMargin + leftWidth + photoSpacing,
                    y: photoAreaTop + rightCellHeight + photoSpacing,
                    width: rightWidth,
                    height: rightCellHeight
                )
                _ = drawRoundedImageFill(photos[2], in: rightBottomRect, cornerRadius: cornerRadius, context: cgContext)

            default: // 4장
                // 4장: 2x2 그리드 (꽉 차게)
                let cellWidth = (availableWidth - photoSpacing) / 2
                let cellHeight = (photoAreaHeight - photoSpacing) / 2

                for (index, photo) in photos.enumerated() {
                    let row = index / 2
                    let col = index % 2
                    let photoRect = CGRect(
                        x: horizontalMargin + CGFloat(col) * (cellWidth + photoSpacing),
                        y: photoAreaTop + CGFloat(row) * (cellHeight + photoSpacing),
                        width: cellWidth,
                        height: cellHeight
                    )
                    let drawnRect = drawRoundedImageFill(photo, in: photoRect, cornerRadius: cornerRadius, context: cgContext)
                    photoAreaBottom = max(photoAreaBottom, drawnRect.maxY)
                }
            }

            // 4. 하단 정보 영역 (컴팩트 + 균형잡힌 배치)
            let textStartY = photoAreaBottom + photoToTextGap
            let maxTextWidth = size.width - (horizontalMargin * 2)

            // 제목 (Bold, 중앙 정렬)
            let titleFont = UIFont.systemFont(ofSize: 38, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let truncatedTitle = truncateText(data.shareTitle, maxLines: 1, width: maxTextWidth, font: titleFont)
            let titleSize = truncatedTitle.size(withAttributes: titleAttributes)
            truncatedTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: textStartY),
                withAttributes: titleAttributes
            )

            // 통계 (📍 5곳 · 🚗 32km · 2.1~2.3)
            var currentY = textStartY + 38 + 10
            let statsFont = UIFont.systemFont(ofSize: 26, weight: .medium)
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: statsFont,
                .foregroundColor: UIColor(hex: "#6B7B83") ?? .gray
            ]
            let statsText = data.shareStatsWithDate
            let statsSize = statsText.size(withAttributes: statsAttributes)
            statsText.draw(
                at: CGPoint(x: (size.width - statsSize.width) / 2, y: currentY),
                withAttributes: statsAttributes
            )
            currentY += 26 + 10

            // 감성 키워드
            if !configuration.impression.isEmpty {
                let impressionFont = UIFont.systemFont(ofSize: 24, weight: .regular)
                let impressionAttributes: [NSAttributedString.Key: Any] = [
                    .font: impressionFont,
                    .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.7) ?? .darkGray
                ]
                let impressionText = truncateText(configuration.impression, maxLines: 1, width: maxTextWidth, font: impressionFont)
                let impressionSize = impressionText.size(withAttributes: impressionAttributes)
                impressionText.draw(
                    at: CGPoint(x: (size.width - impressionSize.width) / 2, y: currentY),
                    withAttributes: impressionAttributes
                )
                currentY += 24 + 8
            }

            // 해시태그 (최대 3개)
            if !configuration.hashtags.isEmpty {
                let hashtagFont = UIFont.systemFont(ofSize: 22, weight: .medium)
                let hashtagAttributes: [NSAttributedString.Key: Any] = [
                    .font: hashtagFont,
                    .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
                ]
                let hashtagText = configuration.hashtags.prefix(3).map { "#\($0)" }.joined(separator: " ")
                let hashtagSize = hashtagText.size(withAttributes: hashtagAttributes)
                hashtagText.draw(
                    at: CGPoint(x: (size.width - hashtagSize.width) / 2, y: currentY),
                    withAttributes: hashtagAttributes
                )
            }

            // 5. 워터마크 (우하단, 텍스트 영역과 수평 정렬)
            if configuration.showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: size.width - DesignConstants.watermarkWidth - horizontalMargin,
                        y: size.height - bottomMargin - DesignConstants.watermarkIconSize,
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

    /// 둥근 모서리 이미지 그리기 (Aspect Fill - 크롭)
    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        context.saveGState()
        path.addClip()
        drawImageFill(image, in: rect, context: context)
        context.restoreGState()
    }

    /// 이미지를 영역에 맞게 축소 (Aspect Fit - 비율 유지, 크롭 없음)
    private func drawImageFit(_ image: UIImage, in rect: CGRect, context: CGContext, backgroundColor: UIColor = .white) -> CGRect {
        let imageSize = image.size
        let targetSize = rect.size

        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)  // Aspect Fit: min 사용

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let drawRect = CGRect(
            x: rect.minX + (targetSize.width - scaledWidth) / 2,
            y: rect.minY + (targetSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )

        image.draw(in: drawRect)
        return drawRect  // 실제 그려진 영역 반환
    }

    /// 둥근 모서리 이미지 그리기 (세로 사진은 정사각형 크롭, 가로/정사각형은 Fit)
    private func drawRoundedImageAdaptive(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) -> CGRect {
        let imageSize = image.size
        let isPortrait = imageSize.height > imageSize.width * 1.2  // 세로 비율이 1.2배 이상이면 세로 사진

        if isPortrait {
            // 세로 사진: 정사각형에 가깝게 크롭 (Aspect Fill)
            let targetSize = rect.size
            let squareSize = min(targetSize.width, targetSize.height)
            let squareRect = CGRect(
                x: rect.minX + (targetSize.width - squareSize) / 2,
                y: rect.minY + (targetSize.height - squareSize) / 2,
                width: squareSize,
                height: squareSize
            )

            let path = UIBezierPath(roundedRect: squareRect, cornerRadius: cornerRadius)
            context.saveGState()
            path.addClip()
            drawImageFill(image, in: squareRect, context: context)
            context.restoreGState()

            return squareRect
        } else {
            // 가로/정사각형 사진: 기존 Aspect Fit
            return drawRoundedImageFit(image, in: rect, cornerRadius: cornerRadius, context: context)
        }
    }

    /// 둥근 모서리 이미지 그리기 (Aspect Fit - 비율 유지)
    private func drawRoundedImageFit(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext, backgroundColor: UIColor = .white) -> CGRect {
        let imageSize = image.size
        let targetSize = rect.size

        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let drawRect = CGRect(
            x: rect.minX + (targetSize.width - scaledWidth) / 2,
            y: rect.minY + (targetSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )

        // 둥근 모서리로 클리핑
        let path = UIBezierPath(roundedRect: drawRect, cornerRadius: cornerRadius)
        context.saveGState()
        path.addClip()
        image.draw(in: drawRect)
        context.restoreGState()

        return drawRect  // 실제 그려진 영역 반환
    }

    /// 둥근 모서리 이미지 그리기 (Aspect Fill - 크롭하여 영역 꽉 채움)
    private func drawRoundedImageFill(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) -> CGRect {
        let imageSize = image.size
        let targetSize = rect.size

        // Aspect Fill: 영역을 꽉 채우도록 확대 (잘림 허용)
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scale = max(widthRatio, heightRatio)  // Fill은 max 사용

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        // 중앙 정렬 (넘치는 부분은 잘림)
        let drawRect = CGRect(
            x: rect.minX + (targetSize.width - scaledWidth) / 2,
            y: rect.minY + (targetSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )

        // 둥근 모서리로 클리핑 (rect 기준으로 클리핑)
        context.saveGState()
        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        clipPath.addClip()
        image.draw(in: drawRect)
        context.restoreGState()

        return rect  // 클리핑 영역 반환
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
        let spacing: CGFloat = 10

        // 1. 앱 아이콘 그리기 (Bundle에서 직접 로드)
        if let appIcon = loadAppIcon() {
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
            .font: UIFont.systemFont(ofSize: DesignConstants.watermarkTextSize, weight: .bold),
            .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
        ]
        let watermarkText = "Wander"
        let textX = rect.minX + iconSize + spacing
        let textSize = watermarkText.size(withAttributes: watermarkAttributes)
        let textY = rect.minY + (rect.height - textSize.height) / 2
        watermarkText.draw(at: CGPoint(x: textX, y: textY), withAttributes: watermarkAttributes)
    }

    /// 앱 아이콘 로드 (Assets에서 직접)
    private func loadAppIcon() -> UIImage? {
        // WanderIcon 에셋에서 로드 (AppIcon의 복사본)
        if let icon = UIImage(named: "WanderIcon") {
            return icon
        }

        // 폴백: Bundle의 앱 아이콘 파일 직접 로드
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let icon = UIImage(named: lastIcon) {
            return icon
        }

        return nil
    }

    /// 텍스트 자르기 (최대 줄 수 제한, 개선된 버전)
    private func truncateText(_ text: String, maxLines: Int, width: CGFloat, font: UIFont) -> String {
        // 빈 텍스트 처리
        guard !text.isEmpty else { return "" }

        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !words.isEmpty else { return "" }

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
                        // 말줄임 추가 전 너비 확인
                        let ellipsisLine = currentLine + "..."
                        let ellipsisSize = ellipsisLine.size(withAttributes: [.font: font])
                        if ellipsisSize.width > width {
                            // 말줄임도 넘으면 글자 수 줄이기
                            var truncated = currentLine
                            while !truncated.isEmpty {
                                truncated = String(truncated.dropLast())
                                let testEllipsis = truncated + "..."
                                if testEllipsis.size(withAttributes: [.font: font]).width <= width {
                                    result += testEllipsis
                                    return result
                                }
                            }
                        }
                        result += ellipsisLine
                        return result
                    }
                    result += currentLine + "\n"
                    currentLine = word
                } else {
                    // 단어 자체가 너무 길면 글자 단위로 자르기
                    var truncated = word
                    while !truncated.isEmpty {
                        let testTruncated = truncated + "..."
                        if testTruncated.size(withAttributes: [.font: font]).width <= width {
                            currentLine = truncated + "..."
                            break
                        }
                        truncated = String(truncated.dropLast())
                    }
                    if truncated.isEmpty {
                        currentLine = "..."
                    }
                }
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            // 마지막 줄 너비 확인
            let finalSize = currentLine.size(withAttributes: [.font: font])
            if finalSize.width > width {
                var truncated = currentLine
                while !truncated.isEmpty {
                    truncated = String(truncated.dropLast())
                    let testEllipsis = truncated + "..."
                    if testEllipsis.size(withAttributes: [.font: font]).width <= width {
                        result += testEllipsis
                        return result
                    }
                }
            }
            result += currentLine
        }

        return result
    }

    /// 제목용 텍스트 자르기 (15자 기준, 폰트 크기 조정 포함)
    private func truncateTitleText(_ text: String, maxWidth: CGFloat, baseFontSize: CGFloat) -> (String, CGFloat) {
        let baseFont = UIFont.systemFont(ofSize: baseFontSize, weight: .bold)

        // 기본 폰트로 시도
        let textSize = text.size(withAttributes: [.font: baseFont])
        if textSize.width <= maxWidth {
            return (text, baseFontSize)
        }

        // 폰트 크기 축소 시도 (최소 36pt)
        let reducedFontSize = max(baseFontSize - 6, 36)
        let reducedFont = UIFont.systemFont(ofSize: reducedFontSize, weight: .bold)
        let reducedSize = text.size(withAttributes: [.font: reducedFont])
        if reducedSize.width <= maxWidth {
            return (text, reducedFontSize)
        }

        // 그래도 안되면 말줄임
        let truncated = truncateText(text, maxLines: 1, width: maxWidth, font: reducedFont)
        return (truncated, reducedFontSize)
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
