import SwiftUI
import MapKit
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "ResultView")

struct ResultView: View {
    let result: AnalysisResult
    let selectedAssets: [PHAsset]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showShareSheet = false
    @State private var isSaved = false

    init(result: AnalysisResult, selectedAssets: [PHAsset]) {
        self.result = result
        self.selectedAssets = selectedAssets
        logger.info("📊 [ResultView] init - 제목: \(result.title), 장소: \(result.places.count)개")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space6) {
                    // Map Section
                    mapSection

                    // Stats Section
                    statsSection

                    // Timeline Section
                    timelineSection

                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, WanderSpacing.screenMargin)
                .padding(.vertical, WanderSpacing.space4)
            }
            .background(WanderColors.background)
            .navigationTitle(result.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        logger.info("📊 [ResultView] 닫기 버튼 클릭 - 저장됨: \(isSaved)")
                        if isSaved {
                            // 저장된 경우 애니메이션 없이 즉시 닫기
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheetView(result: result)
                    .presentationDetents([.medium])
            }
            .onAppear {
                logger.info("📊 [ResultView] onAppear - 화면 표시됨")
                logger.info("📊 [ResultView] result.title: \(result.title)")
                logger.info("📊 [ResultView] result.places.count: \(result.places.count)")
                logger.info("📊 [ResultView] result.photoCount: \(result.photoCount)")
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            HStack {
                Text("여행 동선")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                NavigationLink(destination: MapDetailView(places: result.places)) {
                    HStack(spacing: WanderSpacing.space1) {
                        Text("전체 보기")
                            .font(WanderTypography.caption1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WanderColors.primary)
                }
            }

            // Mini Map
            Map {
                ForEach(Array(result.places.enumerated()), id: \.element.id) { index, place in
                    Annotation("", coordinate: place.coordinate) {
                        PlaceMarker(number: index + 1, activityType: place.activityType)
                    }
                }

                if result.places.count > 1 {
                    MapPolyline(coordinates: result.places.map { $0.coordinate })
                        .stroke(WanderColors.primary, lineWidth: 3)
                }
            }
            .frame(height: 200)
            .cornerRadius(WanderSpacing.radiusLarge)
            .disabled(true) // Make it non-interactive for preview
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: WanderSpacing.space4) {
            StatCard(
                icon: "mappin.circle.fill",
                value: "\(result.placeCount)",
                label: "방문 장소"
            )

            StatCard(
                icon: "car.fill",
                value: String(format: "%.1f", result.totalDistance),
                label: "이동 거리 (km)"
            )

            StatCard(
                icon: "photo.fill",
                value: "\(result.photoCount)",
                label: "사진"
            )
        }
    }

    // MARK: - Timeline Section
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space4) {
            Text("타임라인")
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)

            ForEach(Array(result.places.enumerated()), id: \.element.id) { index, place in
                TimelineCard(
                    place: place,
                    index: index,
                    isLast: index == result.places.count - 1
                )
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: WanderSpacing.space3) {
            Button(action: saveRecord) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                    Text(isSaved ? "저장 완료" : "기록 저장하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(isSaved ? WanderColors.success : WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
            .disabled(isSaved)

            Button(action: { showShareSheet = true }) {
                HStack(spacing: WanderSpacing.space2) {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(WanderColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                        .stroke(WanderColors.border, lineWidth: 1)
                )
            }
        }
        .padding(.top, WanderSpacing.space4)
    }

    // MARK: - Save Record
    private func saveRecord() {
        let record = TravelRecord(
            title: result.title,
            startDate: result.startDate,
            endDate: result.endDate
        )
        record.totalDistance = result.totalDistance
        record.placeCount = result.placeCount
        record.photoCount = selectedAssets.count // Use actual selected count

        // Create day
        let day = TravelDay(date: result.startDate, dayNumber: 1)

        // Collect photos that are in clusters
        var savedPhotoIds = Set<String>()

        // Create places from clusters
        for (index, cluster) in result.places.enumerated() {
            let place = Place(
                name: cluster.name,
                address: cluster.address,
                coordinate: cluster.coordinate,
                startTime: cluster.startTime
            )
            place.activityLabel = cluster.activityType.displayName
            place.placeType = cluster.placeType ?? "other"
            place.order = index

            // Save photos to place
            for (photoIndex, asset) in cluster.photos.enumerated() {
                let photo = PhotoItem(
                    assetIdentifier: asset.localIdentifier,
                    capturedAt: asset.creationDate,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                photo.order = photoIndex
                place.photos.append(photo)
                savedPhotoIds.insert(asset.localIdentifier)
            }

            day.places.append(place)
        }

        // Find photos not in any cluster (no GPS or filtered out)
        let uncategorizedAssets = selectedAssets.filter { !savedPhotoIds.contains($0.localIdentifier) }

        if !uncategorizedAssets.isEmpty {
            // Create "미분류" place for uncategorized photos
            let uncategorizedPlace = Place(
                name: "미분류 사진",
                address: "",
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                startTime: uncategorizedAssets.first?.creationDate ?? Date()
            )
            uncategorizedPlace.activityLabel = "기타"
            uncategorizedPlace.placeType = "other"
            uncategorizedPlace.order = result.places.count

            for (photoIndex, asset) in uncategorizedAssets.enumerated() {
                let photo = PhotoItem(
                    assetIdentifier: asset.localIdentifier,
                    capturedAt: asset.creationDate,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                photo.order = photoIndex
                uncategorizedPlace.photos.append(photo)
            }

            day.places.append(uncategorizedPlace)
            record.placeCount += 1
            logger.info("💾 [ResultView] 미분류 사진 \(uncategorizedAssets.count)장 추가")
        }

        record.days.append(day)

        modelContext.insert(record)

        logger.info("💾 [ResultView] 저장 완료 - 장소: \(record.placeCount), 사진: \(selectedAssets.count)")

        withAnimation {
            isSaved = true
        }
    }
}

// MARK: - Place Marker
struct PlaceMarker: View {
    let number: Int
    let activityType: ActivityType

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 4)

            Circle()
                .fill(WanderColors.primary)
                .frame(width: 28, height: 28)

            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: WanderSpacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(WanderColors.primary)

            Text(value)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(label)
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }
}

// MARK: - Timeline Card
struct TimelineCard: View {
    let place: PlaceCluster
    let index: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WanderSpacing.space4) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Number circle
                ZStack {
                    Circle()
                        .fill(place.activityType.color)
                        .frame(width: 36, height: 36)

                    Text(place.activityType.emoji)
                        .font(.system(size: 16))
                }

                // Connector line
                if !isLast {
                    Rectangle()
                        .fill(WanderColors.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                // Time
                Text(formatTime(place.startTime))
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textTertiary)

                // Place name
                Text(place.name)
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                // Address
                if !place.address.isEmpty {
                    Text(place.address)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                        .lineLimit(1)
                }

                // Activity tag
                HStack(spacing: WanderSpacing.space1) {
                    Text(place.activityType.emoji)
                    Text(place.activityType.displayName)
                }
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space2)
                .padding(.vertical, WanderSpacing.space1)
                .background(place.activityType.color)
                .cornerRadius(WanderSpacing.radiusSmall)

                // Photo count
                Text("사진 \(place.photos.count)장")
                    .font(WanderTypography.caption2)
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(.bottom, isLast ? 0 : WanderSpacing.space4)

            Spacer()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet View
struct ShareSheetView: View {
    let result: AnalysisResult
    @Environment(\.dismiss) private var dismiss
    @AppStorage("includeWatermark") private var includeWatermark = true

    @State private var selectedFormat: ExportFormat = .image
    @State private var isExporting = false
    @State private var showActivitySheet = false
    @State private var exportedImage: UIImage?
    @State private var exportedText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space5) {
                // Format Selection
                VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                    Text("내보내기 형식")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    ForEach(ExportFormat.allCases) { format in
                        ExportFormatRow(
                            format: format,
                            isSelected: selectedFormat == format,
                            onSelect: { selectedFormat = format }
                        )
                    }
                }

                Divider()

                // Options
                VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                    Text("옵션")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    Toggle("워터마크 포함", isOn: $includeWatermark)
                        .tint(WanderColors.primary)

                    Text("'Wander' 로고가 하단에 표시됩니다.")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                }

                Spacer()

                // Export Button
                Button(action: performExport) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "내보내는 중..." : "내보내기")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(isExporting)
            }
            .padding(WanderSpacing.screenMargin)
            .navigationTitle("공유하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let image = exportedImage {
                    ActivityViewController(activityItems: [image])
                } else if !exportedText.isEmpty {
                    ActivityViewController(activityItems: [exportedText])
                }
            }
        }
    }

    private func performExport() {
        isExporting = true
        let exportService = ExportService.shared

        Task {
            switch selectedFormat {
            case .image:
                if let image = await exportService.exportAsImage(result: result, includeWatermark: includeWatermark) {
                    await MainActor.run {
                        exportedImage = image
                        exportedText = ""
                        isExporting = false
                        showActivitySheet = true
                    }
                }

            case .text:
                let text = exportService.exportAsText(result: result, includeWatermark: includeWatermark)
                await MainActor.run {
                    exportedText = text
                    exportedImage = nil
                    isExporting = false
                    showActivitySheet = true
                }

            case .markdown:
                let markdown = exportService.exportAsMarkdown(result: result, includeWatermark: includeWatermark)
                await MainActor.run {
                    exportedText = markdown
                    exportedImage = nil
                    isExporting = false
                    showActivitySheet = true
                }

            case .deeplink:
                if let message = exportService.createShareMessage(result: result) {
                    await MainActor.run {
                        exportedText = message
                        exportedImage = nil
                        isExporting = false
                        showActivitySheet = true
                    }
                } else {
                    await MainActor.run {
                        isExporting = false
                    }
                }
            }
        }
    }
}

// MARK: - Export Format Row
struct ExportFormatRow: View {
    let format: ExportFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WanderSpacing.space3) {
                Image(systemName: format.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? WanderColors.primary : WanderColors.textSecondary)
                    .frame(width: 28)

                Text(format.displayName)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(WanderColors.primary)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(WanderColors.border)
                }
            }
            .padding(WanderSpacing.space3)
            .background(isSelected ? WanderColors.primaryPale : WanderColors.surface)
            .cornerRadius(WanderSpacing.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: WanderSpacing.radiusMedium)
                    .stroke(isSelected ? WanderColors.primary : WanderColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activity View Controller (UIKit Wrapper)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ResultView(
        result: AnalysisResult(),
        selectedAssets: []
    )
}
