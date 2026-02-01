import SwiftUI
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "QuickModeView")

/// "지금 뭐해?" 퀵 모드 뷰
struct QuickModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recentPhotos: [PHAsset] = []
    @State private var selectedAssets: [PHAsset] = []
    @State private var isLoading = true
    @State private var showAnalyzing = false
    @State private var analysisResult: QuickModeResult?
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if recentPhotos.isEmpty {
                    emptyStateView
                } else {
                    photoSelectionView
                }

                // Bottom action bar
                if !selectedAssets.isEmpty {
                    actionBar
                }
            }
            .background(WanderColors.background)
            .navigationTitle("지금 뭐해?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                logger.info("💬 [QuickMode] 화면 나타남")
                loadRecentPhotos()
            }
            .fullScreenCover(isPresented: $showAnalyzing) {
                QuickModeAnalyzingView(
                    selectedAssets: selectedAssets,
                    onComplete: { result in
                        logger.info("💬 [QuickMode] 분석 완료 - 결과 수신")
                        self.analysisResult = result
                        self.showAnalyzing = false
                        // fullScreenCover 닫힌 후 sheet 열기 (딜레이 필요)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            logger.info("💬 [QuickMode] 결과 화면 표시")
                            self.showResult = true
                        }
                    },
                    onCancel: {
                        logger.info("💬 [QuickMode] 분석 취소")
                        self.showAnalyzing = false
                    }
                )
            }
            .sheet(isPresented: $showResult) {
                if let result = analysisResult {
                    QuickModeResultView(result: result)
                } else {
                    // Fallback: 결과가 없으면 닫기
                    Text("결과를 불러올 수 없습니다")
                        .onAppear {
                            logger.error("💬 [QuickMode] 결과 없음 - sheet 닫기")
                            showResult = false
                        }
                }
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: WanderSpacing.space4) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("최근 사진을 불러오는 중...")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("최근 24시간 내 촬영한\n사진이 없어요")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("사진을 촬영하고 다시 시도해 보세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Photo Selection View
    private var photoSelectionView: some View {
        VStack(spacing: WanderSpacing.space4) {
            // Header
            HStack {
                Text("최근 24시간 (\(recentPhotos.count)장)")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)
                Spacer()

                if selectedAssets.count < recentPhotos.count && selectedAssets.count < 10 {
                    Button("전체 선택") {
                        selectedAssets = Array(recentPhotos.prefix(10))
                    }
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.primary)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.top, WanderSpacing.space4)

            // Photo grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ], spacing: 4) {
                    ForEach(recentPhotos, id: \.localIdentifier) { asset in
                        QuickModePhotoCell(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset),
                            selectionOrder: selectedAssets.firstIndex(of: asset).map { $0 + 1 }
                        ) {
                            toggleSelection(asset)
                        }
                    }
                }
                .padding(.horizontal, WanderSpacing.space2)
            }

            // Info text
            Text("최대 10장까지 선택할 수 있어요")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.textTertiary)
                .padding(.bottom, WanderSpacing.space2)
        }
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedAssets.count)장 선택됨")
                        .font(WanderTypography.headline)
                        .foregroundColor(WanderColors.textPrimary)

                    let withGPS = selectedAssets.filter { $0.location != nil }.count
                    Text("GPS 정보 있음: \(withGPS)장")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Spacer()

                Button(action: { showAnalyzing = true }) {
                    Text("분석하기")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, WanderSpacing.space6)
                        .padding(.vertical, WanderSpacing.space3)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusFull)
                }
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
        }
    }

    // MARK: - Helper Functions
    private func loadRecentPhotos() {
        logger.info("💬 [QuickMode] 최근 24시간 사진 로드 시작")

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@",
            yesterday as NSDate
        )

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        logger.info("💬 [QuickMode] 최근 24시간 사진: \(assets.count)장")

        DispatchQueue.main.async {
            self.recentPhotos = assets
            self.isLoading = false
        }
    }

    private func toggleSelection(_ asset: PHAsset) {
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        } else if selectedAssets.count < 10 {
            selectedAssets.append(asset)
        }
    }
}

// MARK: - Quick Mode Photo Cell
struct QuickModePhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let selectionOrder: Int?
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(WanderColors.surface)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                }

                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(WanderColors.primary.opacity(0.3))

                    ZStack {
                        Circle()
                            .fill(WanderColors.primary)
                            .frame(width: 20, height: 20)

                        if let order = selectionOrder {
                            Text("\(order)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(4)
                }

                // GPS indicator
                if asset.location != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                                .padding(2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(2)
                            Spacer()
                        }
                    }
                    .padding(2)
                }
            }
            .cornerRadius(WanderSpacing.radiusSmall)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
}

// MARK: - Quick Mode Result Model
struct QuickModeResult {
    var summary: String
    var placeName: String
    var address: String
    var time: String
    var photos: [UIImage]
    var coordinate: CLLocationCoordinate2D?
}

// MARK: - Quick Mode Analyzing View
import CoreLocation

struct QuickModeAnalyzingView: View {
    let selectedAssets: [PHAsset]
    let onComplete: (QuickModeResult) -> Void
    let onCancel: () -> Void

    @State private var progress: Double = 0
    @State private var currentStep = "분석 준비 중..."

    var body: some View {
        VStack(spacing: WanderSpacing.space6) {
            Spacer()

            // Progress circle
            ZStack {
                Circle()
                    .stroke(WanderColors.primaryPale, lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(WanderColors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(WanderColors.primary)
            }

            VStack(spacing: WanderSpacing.space2) {
                Text("분석 중...")
                    .font(WanderTypography.title3)
                    .foregroundColor(WanderColors.textPrimary)

                Text(currentStep)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()

            Button("취소") {
                onCancel()
            }
            .foregroundColor(WanderColors.textSecondary)
            .padding(.bottom, WanderSpacing.space8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WanderColors.background)
        .ignoresSafeArea()
        .task {
            await analyze()
        }
    }

    private func analyze() async {
        // Step 1: Load photos
        currentStep = "사진 정보 추출 중..."
        progress = 0.2
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Step 2: Get location
        currentStep = "위치 정보 확인 중..."
        progress = 0.5

        var placeName = "알 수 없는 장소"
        var address = ""
        var coordinate: CLLocationCoordinate2D?

        // Get first photo with GPS
        if let firstWithGPS = selectedAssets.first(where: { $0.location != nil }),
           let location = firstWithGPS.location {
            coordinate = location.coordinate

            // Reverse geocode
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
               let placemark = placemarks.first {
                placeName = placemark.name ?? placemark.locality ?? "알 수 없는 장소"
                address = [placemark.locality, placemark.subLocality].compactMap { $0 }.joined(separator: " ")
            }
        }

        progress = 0.7
        currentStep = "결과 생성 중..."
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Step 3: Load photo images
        var photos: [UIImage] = []
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true

        for asset in selectedAssets.prefix(4) {
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 300, height: 300),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    photos.append(image)
                }
            }
        }

        progress = 1.0

        // Create result
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "a h시 m분"
        timeFormatter.locale = Locale(identifier: "ko_KR")
        let timeString = timeFormatter.string(from: selectedAssets.first?.creationDate ?? Date())

        // Generate summary
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        switch hour {
        case 6..<12: timeOfDay = "아침"
        case 12..<14: timeOfDay = "점심"
        case 14..<18: timeOfDay = "오후"
        case 18..<22: timeOfDay = "저녁"
        default: timeOfDay = "밤"
        }

        let summary = "\(placeName)에서 \(timeOfDay) 시간을 보내는 중!"

        let result = QuickModeResult(
            summary: summary,
            placeName: placeName,
            address: address,
            time: timeString,
            photos: photos,
            coordinate: coordinate
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run {
            onComplete(result)
        }
    }
}

// MARK: - Quick Mode Result View
struct QuickModeResultView: View {
    let result: QuickModeResult
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: WanderSpacing.space5) {
                    // Photo grid
                    if !result.photos.isEmpty {
                        photoGridSection
                    }

                    // Summary card
                    summaryCard

                    // Share options
                    shareOptionsSection
                }
                .padding(WanderSpacing.screenMargin)
            }
            .background(WanderColors.background)
            .navigationTitle("결과")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [result.summary])
            }
        }
    }

    private var photoGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 4),
            GridItem(.flexible(), spacing: 4)
        ], spacing: 4) {
            ForEach(0..<result.photos.count, id: \.self) { index in
                Image(uiImage: result.photos[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 150)
                    .clipped()
                    .cornerRadius(WanderSpacing.radiusMedium)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: WanderSpacing.space3) {
            Text(result.summary)
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            Divider()

            HStack(spacing: WanderSpacing.space4) {
                Label(result.placeName, systemImage: "mappin")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)

                Label(result.time, systemImage: "clock")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
        .cornerRadius(WanderSpacing.radiusLarge)
    }

    private var shareOptionsSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            Button(action: { showShareSheet = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("공유하기")
                }
                .font(WanderTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: WanderSpacing.buttonHeight)
                .background(WanderColors.primary)
                .cornerRadius(WanderSpacing.radiusLarge)
            }
        }
    }
}

#Preview {
    QuickModeView()
}
