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

    // MARK: - Public Methods

    /// 공유 이미지 생성
    func generateImage(
        photos: [UIImage],
        data: ShareableData,
        configuration: ShareConfiguration
    ) async throws -> UIImage {
        logger.info("📸 [ShareImageGenerator] 이미지 생성 시작 - 스타일: \(configuration.templateStyle.rawValue)")

        guard !photos.isEmpty else {
            throw ShareError.noPhotosSelected
        }

        let size = configuration.destination.imageSize

        // 스타일에 따른 렌더링
        let image: UIImage

        switch configuration.templateStyle {
        case .modernGlass:
            image = renderModernGlass(
                photos: photos,
                data: data,
                size: size,
                showWatermark: configuration.showWatermark
            )
        case .polaroidGrid:
            image = renderPolaroidGrid(
                photos: photos,
                data: data,
                size: size,
                showWatermark: configuration.showWatermark
            )
        case .cleanMinimal:
            image = renderCleanMinimal(
                photos: photos,
                data: data,
                size: size,
                showWatermark: configuration.showWatermark
            )
        }

        logger.info("📸 [ShareImageGenerator] 이미지 생성 완료 - 크기: \(Int(size.width))x\(Int(size.height))")

        return image
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

    // MARK: - Modern Glass Template

    private func renderModernGlass(
        photos: [UIImage],
        data: ShareableData,
        size: CGSize,
        showWatermark: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 메인 사진 배경 (전체)
            if let mainPhoto = photos.first {
                drawImageFill(mainPhoto, in: CGRect(origin: .zero, size: size), context: cgContext)
            }

            // 2. 하단 글래스 패널
            let panelHeight: CGFloat = 180
            let panelMargin: CGFloat = 40
            let panelRect = CGRect(
                x: panelMargin,
                y: size.height - panelHeight - 60,
                width: size.width - (panelMargin * 2),
                height: panelHeight
            )

            drawGlassPanel(in: panelRect, context: cgContext)

            // 3. 패널 내 텍스트
            let textMargin: CGFloat = 24

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let title = data.shareTitle
            title.draw(
                at: CGPoint(x: panelRect.minX + textMargin, y: panelRect.minY + textMargin),
                withAttributes: titleAttributes
            )

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.8) ?? .darkGray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳  ·  🚗 \(Int(data.shareTotalDistance))km"
            stats.draw(
                at: CGPoint(x: panelRect.minX + textMargin, y: panelRect.minY + textMargin + 40),
                withAttributes: statsAttributes
            )

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            data.shareDateRange.draw(
                at: CGPoint(x: panelRect.minX + textMargin, y: panelRect.minY + textMargin + 70),
                withAttributes: dateAttributes
            )

            // 워터마크
            if showWatermark {
                drawWatermark(
                    in: CGRect(
                        x: panelRect.maxX - 100,
                        y: panelRect.maxY - 40,
                        width: 80,
                        height: 24
                    ),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Polaroid Grid Template

    private func renderPolaroidGrid(
        photos: [UIImage],
        data: ShareableData,
        size: CGSize,
        showWatermark: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 배경 (연한 베이지/크림)
            UIColor(hex: "#FAF8F5")?.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 폴라로이드 그리드 (최대 3장)
            let polaroidPhotos = Array(photos.prefix(3))
            let polaroidSize = CGSize(width: 280, height: 340)
            let startY: CGFloat = 80

            for (index, photo) in polaroidPhotos.enumerated() {
                let rotation: CGFloat = [CGFloat(-5), CGFloat(3), CGFloat(-2)][index % 3] * .pi / 180
                let offsetX: CGFloat = [CGFloat(60), CGFloat(400), CGFloat(740)][index % 3]

                cgContext.saveGState()

                // 회전 중심점
                let centerX = offsetX + polaroidSize.width / 2
                let centerY = startY + polaroidSize.height / 2
                cgContext.translateBy(x: centerX, y: centerY)
                cgContext.rotate(by: rotation)
                cgContext.translateBy(x: -centerX, y: -centerY)

                // 폴라로이드 프레임 (흰색 + 그림자)
                let frameRect = CGRect(x: offsetX, y: startY, width: polaroidSize.width, height: polaroidSize.height)

                cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: UIColor.black.withAlphaComponent(0.15).cgColor)
                UIColor.white.setFill()
                cgContext.fill(frameRect)
                cgContext.setShadow(offset: .zero, blur: 0)

                // 사진 영역 (프레임 안쪽)
                let photoRect = CGRect(
                    x: offsetX + 15,
                    y: startY + 15,
                    width: polaroidSize.width - 30,
                    height: polaroidSize.height - 60
                )
                drawImageFill(photo, in: photoRect, context: cgContext)

                cgContext.restoreGState()
            }

            // 3. 하단 정보
            let infoY = startY + polaroidSize.height + 120

            // 제목 (손글씨 느낌)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Noteworthy-Bold", size: 32) ?? UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let titleSize = data.shareTitle.size(withAttributes: titleAttributes)
            data.shareTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: infoY),
                withAttributes: titleAttributes
            )

            // 날짜
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            let dateSize = data.shareDateRange.size(withAttributes: dateAttributes)
            data.shareDateRange.draw(
                at: CGPoint(x: (size.width - dateSize.width) / 2, y: infoY + 50),
                withAttributes: dateAttributes
            )

            // 워터마크
            if showWatermark {
                drawWatermark(
                    in: CGRect(x: size.width - 120, y: size.height - 60, width: 80, height: 24),
                    context: cgContext
                )
            }
        }
    }

    // MARK: - Clean Minimal Template

    private func renderCleanMinimal(
        photos: [UIImage],
        data: ShareableData,
        size: CGSize,
        showWatermark: Bool
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext

            // 1. 배경 (화이트)
            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            // 2. 메인 사진 (둥근 모서리)
            if let mainPhoto = photos.first {
                let photoMargin: CGFloat = 60
                let photoHeight: CGFloat = size.height * 0.6
                let photoRect = CGRect(
                    x: photoMargin,
                    y: photoMargin,
                    width: size.width - (photoMargin * 2),
                    height: photoHeight
                )

                // 둥근 모서리 클리핑
                let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 24)
                cgContext.saveGState()
                path.addClip()
                drawImageFill(mainPhoto, in: photoRect, context: cgContext)
                cgContext.restoreGState()
            }

            // 3. 하단 정보 (센터 정렬)
            let infoY = size.height * 0.7 + 40

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            let titleSize = data.shareTitle.size(withAttributes: titleAttributes)
            data.shareTitle.draw(
                at: CGPoint(x: (size.width - titleSize.width) / 2, y: infoY),
                withAttributes: titleAttributes
            )

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(hex: "#5A6B73") ?? .gray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳  ·  🚗 \(Int(data.shareTotalDistance))km"
            let statsSize = stats.size(withAttributes: statsAttributes)
            stats.draw(
                at: CGPoint(x: (size.width - statsSize.width) / 2, y: infoY + 45),
                withAttributes: statsAttributes
            )

            // 워터마크
            if showWatermark {
                drawWatermark(
                    in: CGRect(x: (size.width - 80) / 2, y: size.height - 80, width: 80, height: 24),
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
            let stickerHeight: CGFloat = 120
            let stickerMargin: CGFloat = 60
            let stickerRect = CGRect(
                x: stickerMargin,
                y: size.height - stickerHeight - 180,
                width: size.width - (stickerMargin * 2),
                height: stickerHeight
            )

            drawGlassPanel(in: stickerRect, context: cgContext, cornerRadius: 16)

            // 3. 스티커 내 텍스트
            let textMargin: CGFloat = 20

            // 제목
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor(hex: "#1A2B33") ?? .black
            ]
            data.shareTitle.draw(
                at: CGPoint(x: stickerRect.minX + textMargin, y: stickerRect.minY + textMargin),
                withAttributes: titleAttributes
            )

            // 통계
            let statsAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(hex: "#1A2B33")?.withAlphaComponent(0.8) ?? .darkGray
            ]
            let stats = "📍 \(data.sharePlaceCount)곳 방문"
            stats.draw(
                at: CGPoint(x: stickerRect.minX + textMargin, y: stickerRect.minY + textMargin + 35),
                withAttributes: statsAttributes
            )

            // 워터마크
            if showWatermark {
                drawWatermark(
                    in: CGRect(x: size.width - 120, y: size.height - 80, width: 80, height: 24),
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

    /// 글래스 패널 그리기
    private func drawGlassPanel(in rect: CGRect, context: CGContext, cornerRadius: CGFloat = 20) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        // 그림자
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 5), blur: 10, color: UIColor.black.withAlphaComponent(0.1).cgColor)
        UIColor.white.withAlphaComponent(0.75).setFill()
        path.fill()
        context.restoreGState()
    }

    /// 워터마크 그리기
    private func drawWatermark(in rect: CGRect, context: CGContext) {
        let watermarkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor(hex: "#87CEEB") ?? .systemBlue
        ]
        let watermark = "🗺️ Wander"
        watermark.draw(at: CGPoint(x: rect.minX, y: rect.minY), withAttributes: watermarkAttributes)
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
