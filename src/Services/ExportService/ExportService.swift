import Foundation
import SwiftUI
import MapKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ExportService")

/// 내보내기 서비스 (이미지 공유 전용)
final class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Text Export

    /// 텍스트 형식으로 내보내기
    func exportAsText(result: AnalysisResult, includeWatermark: Bool = true) -> String {
        logger.info("📤 [ExportService] 텍스트 내보내기 시작")

        var text = """
        \(result.title)

        📅 \(formatDate(result.startDate)) ~ \(formatDate(result.endDate))
        📍 \(result.placeCount)개 장소 | 📸 \(result.photoCount)장 | 🚗 \(String(format: "%.1f", result.totalDistance))km

        --- 타임라인 ---

        """

        // Group places by date
        let groupedByDate = groupPlacesByDate(result.places)
        let sortedDates = groupedByDate.keys.sorted()

        for (dayIndex, date) in sortedDates.enumerated() {
            let dayNumber = dayIndex + 1
            text += """

            ━━━ Day \(dayNumber) · \(formatDateWithWeekday(date)) ━━━

            """

            if let placesForDay = groupedByDate[date] {
                let sortedPlaces = placesForDay.sorted { $0.startTime < $1.startTime }
                for (placeIndex, place) in sortedPlaces.enumerated() {
                    text += """
                    [\(placeIndex + 1)] \(formatTime(place.startTime))
                    \(place.activityType.emoji) \(place.name)
                    📍 \(place.address)
                    📸 사진 \(place.photos.count)장

                    """
                }
            }
        }

        if includeWatermark {
            text += "\n---\n🗺️ Wander로 기록했어요"
        }

        logger.info("📤 [ExportService] 텍스트 내보내기 완료")
        return text
    }

    // MARK: - Markdown Export

    /// Markdown 형식으로 내보내기
    func exportAsMarkdown(result: AnalysisResult, includeWatermark: Bool = true) -> String {
        logger.info("📤 [ExportService] Markdown 내보내기 시작")

        var markdown = """
        # \(result.title)

        **기간**: \(formatDate(result.startDate)) ~ \(formatDate(result.endDate))

        | 항목 | 값 |
        |------|-----|
        | 방문 장소 | \(result.placeCount)개 |
        | 사진 | \(result.photoCount)장 |
        | 이동 거리 | \(String(format: "%.1f", result.totalDistance))km |

        ## 타임라인

        """

        for (index, place) in result.places.enumerated() {
            markdown += """

            ### \(index + 1). \(place.name)

            - **시간**: \(formatTime(place.startTime))
            - **주소**: \(place.address)
            - **활동**: \(place.activityType.emoji) \(place.activityType.displayName)
            - **사진**: \(place.photos.count)장

            """
        }

        if includeWatermark {
            markdown += "\n---\n\n*🗺️ Wander로 기록했어요*"
        }

        logger.info("📤 [ExportService] Markdown 내보내기 완료")
        return markdown
    }

    // MARK: - Image Export

    /// 이미지로 내보내기 (1080x1920)
    func exportAsImage(result: AnalysisResult, includeWatermark: Bool = true) async -> UIImage? {
        logger.info("📤 [ExportService] 이미지 내보내기 시작")

        // Pre-load thumbnails
        let allAssets = result.places.flatMap { $0.photos }
        let thumbnails = await loadThumbnails(from: allAssets, maxCount: 6)
        logger.info("📤 [ExportService] 썸네일 \(thumbnails.count)개 로드 완료")

        let size = CGSize(width: 1080, height: 1920)

        // UIKit 렌더링
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            // Background
            UIColor.white.setFill()
            context.fill(rect)

            // Draw content
            drawHeader(in: context.cgContext, result: result, size: size)
            drawStats(in: context.cgContext, result: result, size: size)
            let timelineEndY = drawTimeline(in: context.cgContext, result: result, size: size)
            drawPhotos(thumbnails: thumbnails, startY: timelineEndY + 40, size: size)

            if includeWatermark {
                drawWatermark(in: context.cgContext, size: size)
            }
        }

        logger.info("📤 [ExportService] 이미지 내보내기 완료")
        return image
    }

    /// PHAsset에서 썸네일 로드
    private func loadThumbnails(from assets: [PHAsset], maxCount: Int) async -> [UIImage] {
        let assetsToLoad = Array(assets.prefix(maxCount))
        var thumbnails: [UIImage] = []

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 400, height: 400)

        for asset in assetsToLoad {
            await withCheckedContinuation { continuation in
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        thumbnails.append(image)
                    }
                    continuation.resume()
                }
            }
        }

        return thumbnails
    }

    // MARK: - Private Drawing Methods

    private func drawHeader(in context: CGContext, result: AnalysisResult, size: CGSize) {
        // Title
        let titleFont = UIFont.systemFont(ofSize: 48, weight: .bold)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)

        let titleRect = CGRect(x: 60, y: 80, width: size.width - 120, height: 70)
        let titleString = NSAttributedString(
            string: result.title,
            attributes: [
                .font: titleFont,
                .foregroundColor: titleColor
            ]
        )
        titleString.draw(in: titleRect)

        // Date
        let dateFont = UIFont.systemFont(ofSize: 28, weight: .regular)
        let dateColor = UIColor(red: 0.35, green: 0.42, blue: 0.45, alpha: 1)

        let dateRect = CGRect(x: 60, y: 160, width: size.width - 120, height: 40)
        let dateString = NSAttributedString(
            string: "📅 \(formatDate(result.startDate)) ~ \(formatDate(result.endDate))",
            attributes: [
                .font: dateFont,
                .foregroundColor: dateColor
            ]
        )
        dateString.draw(in: dateRect)
    }

    private func drawStats(in context: CGContext, result: AnalysisResult, size: CGSize) {
        let statsY: CGFloat = 240

        // Background
        let statsRect = CGRect(x: 40, y: statsY, width: size.width - 80, height: 150)
        let statsPath = UIBezierPath(roundedRect: statsRect, cornerRadius: 24)

        UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1).setFill()
        statsPath.fill()

        // Stats
        let statFont = UIFont.systemFont(ofSize: 36, weight: .bold)
        let labelFont = UIFont.systemFont(ofSize: 20, weight: .regular)
        let statColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let labelColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 1)

        let stats = [
            ("📍", "\(result.placeCount)", "방문 장소"),
            ("📸", "\(result.photoCount)", "사진"),
            ("🚗", String(format: "%.1f", result.totalDistance), "km")
        ]

        let statWidth = (size.width - 80) / 3
        for (index, stat) in stats.enumerated() {
            let x = 40 + CGFloat(index) * statWidth
            let centerX = x + statWidth / 2

            // Icon + Value
            let valueString = NSAttributedString(
                string: "\(stat.0) \(stat.1)",
                attributes: [.font: statFont, .foregroundColor: statColor]
            )
            let valueSize = valueString.size()
            valueString.draw(at: CGPoint(x: centerX - valueSize.width / 2, y: statsY + 35))

            // Label
            let labelString = NSAttributedString(
                string: stat.2,
                attributes: [.font: labelFont, .foregroundColor: labelColor]
            )
            let labelSize = labelString.size()
            labelString.draw(at: CGPoint(x: centerX - labelSize.width / 2, y: statsY + 95))
        }
    }

    @discardableResult
    private func drawTimeline(in context: CGContext, result: AnalysisResult, size: CGSize) -> CGFloat {
        var currentY: CGFloat = 440

        let titleFont = UIFont.systemFont(ofSize: 32, weight: .bold)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)

        // Section title
        let sectionTitle = NSAttributedString(
            string: "타임라인",
            attributes: [.font: titleFont, .foregroundColor: titleColor]
        )
        sectionTitle.draw(at: CGPoint(x: 60, y: currentY))
        currentY += 60

        // Fonts and colors
        let dayHeaderFont = UIFont.systemFont(ofSize: 24, weight: .bold)
        let dayDateFont = UIFont.systemFont(ofSize: 18, weight: .regular)
        let placeFont = UIFont.systemFont(ofSize: 22, weight: .semibold)
        let timeFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let addressFont = UIFont.systemFont(ofSize: 14, weight: .regular)

        let placeColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)
        let timeColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 1)
        let addressColor = UIColor(red: 0.35, green: 0.42, blue: 0.45, alpha: 1)
        let primaryColor = UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1) // #87CEEB
        let primaryPaleColor = UIColor(red: 0.91, green: 0.96, blue: 0.99, alpha: 1) // #E8F6FC

        // Group places by date
        let groupedByDate = groupPlacesByDate(result.places)
        let sortedDates = groupedByDate.keys.sorted()

        var totalPlacesDrawn = 0
        let maxPlaces = 4 // Reduced to make room for photos

        for (dayIndex, date) in sortedDates.enumerated() {
            guard totalPlacesDrawn < maxPlaces else { break }

            let dayNumber = dayIndex + 1

            // Draw Day header
            let dayHeaderRect = CGRect(x: 60, y: currentY, width: 80, height: 32)
            let dayHeaderPath = UIBezierPath(roundedRect: dayHeaderRect, cornerRadius: 8)
            primaryPaleColor.setFill()
            dayHeaderPath.fill()

            let dayString = NSAttributedString(
                string: "Day \(dayNumber)",
                attributes: [.font: dayHeaderFont, .foregroundColor: primaryColor]
            )
            let dayStringSize = dayString.size()
            dayString.draw(at: CGPoint(
                x: dayHeaderRect.midX - dayStringSize.width / 2,
                y: dayHeaderRect.midY - dayStringSize.height / 2
            ))

            // Draw date next to Day header
            let dateString = NSAttributedString(
                string: formatDateWithWeekday(date),
                attributes: [.font: dayDateFont, .foregroundColor: timeColor]
            )
            dateString.draw(at: CGPoint(x: 150, y: currentY + 6))

            currentY += 45

            // Draw places for this day
            if let placesForDay = groupedByDate[date] {
                let sortedPlaces = placesForDay.sorted { $0.startTime < $1.startTime }

                for (placeIndex, place) in sortedPlaces.enumerated() {
                    guard totalPlacesDrawn < maxPlaces else { break }

                    let isLastInDay = placeIndex == sortedPlaces.count - 1
                    let isLastOverall = totalPlacesDrawn == maxPlaces - 1

                    // Number circle
                    let circleRect = CGRect(x: 60, y: currentY, width: 40, height: 40)
                    let circlePath = UIBezierPath(ovalIn: circleRect)
                    primaryColor.setFill()
                    circlePath.fill()

                    // Number
                    let numberString = NSAttributedString(
                        string: "\(placeIndex + 1)",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                            .foregroundColor: UIColor.white
                        ]
                    )
                    let numberSize = numberString.size()
                    numberString.draw(at: CGPoint(
                        x: circleRect.midX - numberSize.width / 2,
                        y: circleRect.midY - numberSize.height / 2
                    ))

                    // Connector line (if not last)
                    if !isLastInDay && !isLastOverall {
                        let linePath = UIBezierPath()
                        linePath.move(to: CGPoint(x: 80, y: currentY + 40))
                        linePath.addLine(to: CGPoint(x: 80, y: currentY + 100))
                        UIColor(red: 0.9, green: 0.93, blue: 0.95, alpha: 1).setStroke()
                        linePath.lineWidth = 2
                        linePath.stroke()
                    }

                    // Time
                    let timeString = NSAttributedString(
                        string: formatTime(place.startTime),
                        attributes: [.font: timeFont, .foregroundColor: timeColor]
                    )
                    timeString.draw(at: CGPoint(x: 115, y: currentY - 2))

                    // Place name (truncated if needed)
                    var displayName = "\(place.activityType.emoji) \(place.name)"
                    if displayName.count > 28 {
                        displayName = String(displayName.prefix(28)) + "..."
                    }
                    let placeString = NSAttributedString(
                        string: displayName,
                        attributes: [.font: placeFont, .foregroundColor: placeColor]
                    )
                    placeString.draw(at: CGPoint(x: 115, y: currentY + 18))

                    // Address (truncated)
                    var displayAddress = place.address
                    if displayAddress.count > 40 {
                        displayAddress = String(displayAddress.prefix(40)) + "..."
                    }
                    let addressString = NSAttributedString(
                        string: "📍 \(displayAddress)",
                        attributes: [.font: addressFont, .foregroundColor: addressColor]
                    )
                    addressString.draw(at: CGPoint(x: 115, y: currentY + 45))

                    // Photo count
                    let photoString = NSAttributedString(
                        string: "📸 \(place.photos.count)장",
                        attributes: [.font: addressFont, .foregroundColor: addressColor]
                    )
                    photoString.draw(at: CGPoint(x: 115, y: currentY + 68))

                    currentY += 110
                    totalPlacesDrawn += 1
                }
            }

            // Add spacing between days
            if dayIndex < sortedDates.count - 1 && totalPlacesDrawn < maxPlaces {
                currentY += 15
            }
        }

        // "더보기" indicator if more places
        if result.places.count > totalPlacesDrawn {
            let moreString = NSAttributedString(
                string: "... 외 \(result.places.count - totalPlacesDrawn)곳",
                attributes: [.font: addressFont, .foregroundColor: timeColor]
            )
            moreString.draw(at: CGPoint(x: 115, y: currentY))
            currentY += 30
        }

        return currentY
    }

    private func drawPhotos(thumbnails: [UIImage], startY: CGFloat, size: CGSize) {
        guard !thumbnails.isEmpty else { return }

        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let titleColor = UIColor(red: 0.1, green: 0.17, blue: 0.2, alpha: 1)

        var currentY = startY

        // Section title
        let sectionTitle = NSAttributedString(
            string: "📸 사진",
            attributes: [.font: titleFont, .foregroundColor: titleColor]
        )
        sectionTitle.draw(at: CGPoint(x: 60, y: currentY))
        currentY += 50

        let margin: CGFloat = 60
        let spacing: CGFloat = 12
        let availableWidth = size.width - (margin * 2)
        let cornerRadius: CGFloat = 16

        switch thumbnails.count {
        case 1:
            // Single photo: Full width, larger height
            let photoWidth = availableWidth
            let photoHeight: CGFloat = 350
            let photoRect = CGRect(x: margin, y: currentY, width: photoWidth, height: photoHeight)
            drawRoundedImage(thumbnails[0], in: photoRect, cornerRadius: cornerRadius)

        case 2:
            // Two photos: Side by side
            let photoWidth = (availableWidth - spacing) / 2
            let photoHeight: CGFloat = 280

            let rect1 = CGRect(x: margin, y: currentY, width: photoWidth, height: photoHeight)
            let rect2 = CGRect(x: margin + photoWidth + spacing, y: currentY, width: photoWidth, height: photoHeight)

            drawRoundedImage(thumbnails[0], in: rect1, cornerRadius: cornerRadius)
            drawRoundedImage(thumbnails[1], in: rect2, cornerRadius: cornerRadius)

        case 3:
            // Three photos: One large on left, two stacked on right
            let largeWidth = (availableWidth - spacing) * 0.6
            let smallWidth = (availableWidth - spacing) * 0.4
            let largeHeight: CGFloat = 280
            let smallHeight = (largeHeight - spacing) / 2

            // Large photo on left
            let largeRect = CGRect(x: margin, y: currentY, width: largeWidth, height: largeHeight)
            drawRoundedImage(thumbnails[0], in: largeRect, cornerRadius: cornerRadius)

            // Two small photos on right
            let smallRect1 = CGRect(x: margin + largeWidth + spacing, y: currentY, width: smallWidth, height: smallHeight)
            let smallRect2 = CGRect(x: margin + largeWidth + spacing, y: currentY + smallHeight + spacing, width: smallWidth, height: smallHeight)

            drawRoundedImage(thumbnails[1], in: smallRect1, cornerRadius: cornerRadius)
            drawRoundedImage(thumbnails[2], in: smallRect2, cornerRadius: cornerRadius)

        default:
            // 4+ photos: Grid layout (3 columns)
            let columns = 3
            let photoWidth = (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let photoHeight = photoWidth // Square

            for (index, thumbnail) in thumbnails.prefix(6).enumerated() {
                let row = index / columns
                let col = index % columns

                let x = margin + CGFloat(col) * (photoWidth + spacing)
                let y = currentY + CGFloat(row) * (photoHeight + spacing)

                let rect = CGRect(x: x, y: y, width: photoWidth, height: photoHeight)
                drawRoundedImage(thumbnail, in: rect, cornerRadius: cornerRadius)
            }
        }
    }

    private func drawRoundedImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        UIGraphicsGetCurrentContext()?.saveGState()
        path.addClip()

        // Calculate aspect fill
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height

        var drawRect = rect
        if imageAspect > rectAspect {
            // Image is wider, fit height
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(
                x: rect.midX - scaledWidth / 2,
                y: rect.minY,
                width: scaledWidth,
                height: rect.height
            )
        } else {
            // Image is taller, fit width
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - scaledHeight / 2,
                width: rect.width,
                height: scaledHeight
            )
        }

        image.draw(in: drawRect)
        UIGraphicsGetCurrentContext()?.restoreGState()

        // Draw subtle border
        UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawWatermark(in context: CGContext, size: CGSize) {
        let watermarkFont = UIFont.systemFont(ofSize: 24, weight: .medium)
        let watermarkColor = UIColor(red: 0.54, green: 0.6, blue: 0.64, alpha: 0.8)

        let watermarkString = NSAttributedString(
            string: "🗺️ Wander",
            attributes: [.font: watermarkFont, .foregroundColor: watermarkColor]
        )

        let watermarkSize = watermarkString.size()
        let x = size.width - watermarkSize.width - 40
        let y = size.height - watermarkSize.height - 40

        watermarkString.draw(at: CGPoint(x: x, y: y))
    }

    // MARK: - Deeplink Export

    /// 딥링크 URL 생성
    func createShareableURL(result: AnalysisResult) -> URL? {
        logger.info("📤 [ExportService] 딥링크 생성 시작")

        // Create SharedRecordData from AnalysisResult
        let sharedPlaces = result.places.map { place in
            SharedRecordData.SharedPlaceData(
                name: place.name,
                address: place.address,
                latitude: place.latitude,
                longitude: place.longitude,
                activityType: place.activityType.rawValue,
                visitTime: place.startTime,
                photoCount: place.photos.count
            )
        }

        let sharedData = SharedRecordData(
            title: result.title,
            startDate: result.startDate,
            endDate: result.endDate,
            places: sharedPlaces,
            totalDistance: result.totalDistance,
            photoCount: result.photoCount,
            aiStory: nil
        )

        // Encode to Base64
        guard let base64Data = sharedData.encode() else {
            logger.error("📤 [ExportService] Base64 인코딩 실패")
            return nil
        }

        // Create URL
        var components = URLComponents()
        components.scheme = "wander"
        components.host = "share"
        components.queryItems = [
            URLQueryItem(name: "data", value: base64Data)
        ]

        guard let url = components.url else {
            logger.error("📤 [ExportService] URL 생성 실패")
            return nil
        }

        logger.info("📤 [ExportService] 딥링크 생성 완료: \(url.absoluteString.prefix(100))...")
        return url
    }

    /// 공유 메시지 생성 (딥링크 포함)
    func createShareMessage(result: AnalysisResult) -> String? {
        guard let url = createShareableURL(result: result) else {
            return nil
        }

        let message = """
        🗺️ \(result.title)

        📅 \(formatDate(result.startDate)) ~ \(formatDate(result.endDate))
        📍 \(result.placeCount)개 장소 방문
        📸 \(result.photoCount)장의 추억

        Wander 앱에서 기록 보기:
        \(url.absoluteString)

        ---
        Wander - 여행 사진 AI 스토리텔링
        """

        return message
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 (E)"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    /// 장소를 날짜별로 그룹화
    private func groupPlacesByDate(_ places: [PlaceCluster]) -> [Date: [PlaceCluster]] {
        let calendar = Calendar.current
        var grouped: [Date: [PlaceCluster]] = [:]

        for place in places {
            let dateOnly = calendar.startOfDay(for: place.startTime)
            if grouped[dateOnly] == nil {
                grouped[dateOnly] = []
            }
            grouped[dateOnly]?.append(place)
        }

        return grouped
    }
}
