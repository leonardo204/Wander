import SwiftUI
import Photos
import PhotosUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoSelectionView")

struct PhotoSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PhotoSelectionViewModel()
    @State private var showDatePicker = false

    // Drag selection state
    @State private var isDragging = false
    @State private var dragStartedOnSelected = false
    @State private var photosSelectedDuringDrag: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date Range Filter
                dateRangeSection

                // Quick Select Buttons
                quickSelectSection

                // Photo Grid
                if viewModel.authorizationStatus == .authorized || viewModel.authorizationStatus == .limited {
                    photoGridSection
                } else {
                    permissionRequiredView
                }

                // Bottom Bar with Selection Info
                if !viewModel.selectedAssets.isEmpty {
                    selectionInfoBar
                }
            }
            .background(WanderColors.background)
            .navigationTitle("사진 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(WanderColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        viewModel.startAnalysis()
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(viewModel.selectedAssets.isEmpty ? WanderColors.textDisabled : WanderColors.primary)
                    .disabled(viewModel.selectedAssets.isEmpty)
                }
            }
            .onAppear {
                logger.info("📷 [PhotoSelectionView] 나타남")
                viewModel.checkPermission()
            }
            .onChange(of: viewModel.photos.count) { oldValue, newValue in
                logger.info("📷 [PhotoSelectionView] 사진 로드됨: \(newValue)장")
            }
            .onChange(of: viewModel.selectedAssets.count) { oldValue, newValue in
                logger.info("📷 [PhotoSelectionView] 선택된 사진: \(newValue)장")
            }
            .sheet(isPresented: $showDatePicker) {
                DateRangePickerSheet(
                    startDate: $viewModel.startDate,
                    endDate: $viewModel.endDate,
                    onApply: {
                        viewModel.fetchPhotos()
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $viewModel.showAnalysis) {
                AnalyzingView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Date Range Section
    private var dateRangeSection: some View {
        Button(action: { showDatePicker = true }) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(WanderColors.primary)

                Text(viewModel.dateRangeText)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(WanderColors.textTertiary)
            }
            .padding(WanderSpacing.space4)
            .background(WanderColors.surface)
        }
    }

    // MARK: - Quick Select Section
    private var quickSelectSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WanderSpacing.space2) {
                QuickSelectChip(title: "오늘", isSelected: viewModel.quickSelect == .today) {
                    viewModel.selectQuickRange(.today)
                }
                QuickSelectChip(title: "이번 주", isSelected: viewModel.quickSelect == .thisWeek) {
                    viewModel.selectQuickRange(.thisWeek)
                }
                QuickSelectChip(title: "이번 달", isSelected: viewModel.quickSelect == .thisMonth) {
                    viewModel.selectQuickRange(.thisMonth)
                }
                QuickSelectChip(title: "최근 3개월", isSelected: viewModel.quickSelect == .last3Months) {
                    viewModel.selectQuickRange(.last3Months)
                }
                QuickSelectChip(title: "전체", isSelected: viewModel.quickSelect == .all) {
                    viewModel.selectQuickRange(.all)
                }
            }
            .padding(.horizontal, WanderSpacing.screenMargin)
            .padding(.vertical, WanderSpacing.space3)
        }
        .background(WanderColors.background)
    }

    // MARK: - Photo Grid Section
    private var photoGridSection: some View {
        GeometryReader { outerGeometry in
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(viewModel.photos, id: \.localIdentifier) { asset in
                        DraggablePhotoGridItem(
                            asset: asset,
                            isSelected: viewModel.selectedAssets.contains(asset),
                            selectionOrder: viewModel.selectionOrder(for: asset),
                            isDragging: isDragging
                        ) {
                            if !isDragging {
                                viewModel.toggleSelection(asset)
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(
                                        key: PhotoFramePreferenceKey.self,
                                        value: [asset.localIdentifier: geometry.frame(in: .named("photoGrid"))]
                                    )
                            }
                        )
                    }
                }
                .padding(.bottom, 100) // Extra padding for scroll
            }
            .coordinateSpace(name: "photoGrid")
            .onPreferenceChange(PhotoFramePreferenceKey.self) { frames in
                photoFrames = frames
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        handleDragChanged(value: value, in: outerGeometry)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
        }
    }

    // Photo frames for hit testing
    @State private var photoFrames: [String: CGRect] = [:]

    private func handleDragChanged(value: DragGesture.Value, in geometry: GeometryProxy) {
        if !isDragging {
            // Start dragging
            isDragging = true
            photosSelectedDuringDrag.removeAll()

            // Check if drag started on a selected photo
            let startLocation = value.startLocation
            if let assetId = findAsset(at: startLocation) {
                let asset = viewModel.photos.first { $0.localIdentifier == assetId }
                dragStartedOnSelected = asset != nil && viewModel.selectedAssets.contains(asset!)
            } else {
                dragStartedOnSelected = false
            }

            logger.info("📷 [PhotoSelection] 드래그 선택 시작 - deselect mode: \(dragStartedOnSelected)")
        }

        // Find asset at current drag location
        let location = value.location
        if let assetId = findAsset(at: location) {
            if !photosSelectedDuringDrag.contains(assetId) {
                photosSelectedDuringDrag.insert(assetId)

                if let asset = viewModel.photos.first(where: { $0.localIdentifier == assetId }) {
                    if dragStartedOnSelected {
                        // Deselect mode: remove from selection
                        if viewModel.selectedAssets.contains(asset) {
                            viewModel.removeFromSelection(asset)
                        }
                    } else {
                        // Select mode: add to selection
                        if !viewModel.selectedAssets.contains(asset) {
                            viewModel.addToSelection(asset)
                        }
                    }
                }
            }
        }
    }

    private func handleDragEnded() {
        logger.info("📷 [PhotoSelection] 드래그 선택 종료 - 선택된 사진: \(photosSelectedDuringDrag.count)장")
        isDragging = false
        photosSelectedDuringDrag.removeAll()
    }

    private func findAsset(at location: CGPoint) -> String? {
        for (assetId, frame) in photoFrames {
            if frame.contains(location) {
                return assetId
            }
        }
        return nil
    }

    // MARK: - Permission Required View
    private var permissionRequiredView: some View {
        VStack(spacing: WanderSpacing.space5) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(WanderColors.textTertiary)

            Text("사진 접근 권한이 필요합니다")
                .font(WanderTypography.title3)
                .foregroundColor(WanderColors.textPrimary)

            Text("설정에서 사진 접근을 허용해주세요")
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)

            Button("설정으로 이동") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(WanderTypography.headline)
            .foregroundColor(WanderColors.primary)
            .padding(.top, WanderSpacing.space4)

            Spacer()
        }
    }

    // MARK: - Selection Info Bar
    private var selectionInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.selectedAssets.count)장 선택됨")
                    .font(WanderTypography.headline)
                    .foregroundColor(WanderColors.textPrimary)

                Text(viewModel.selectedPhotosInfo)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Spacer()

            // Select All Button
            if viewModel.selectedAssets.count < viewModel.photos.count {
                Button("전체 선택") {
                    logger.info("📷 [PhotoSelection] 전체 선택")
                    viewModel.selectAll()
                }
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.primary)
                .padding(.trailing, WanderSpacing.space3)
            }

            Button("모두 해제") {
                viewModel.clearSelection()
            }
            .font(WanderTypography.body)
            .foregroundColor(WanderColors.textSecondary)
        }
        .padding(WanderSpacing.space4)
        .background(WanderColors.surface)
    }
}

// MARK: - Quick Select Chip
struct QuickSelectChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(WanderTypography.caption1)
                .foregroundColor(isSelected ? .white : WanderColors.textSecondary)
                .padding(.horizontal, WanderSpacing.space3)
                .padding(.vertical, WanderSpacing.space2)
                .background(isSelected ? WanderColors.primary : WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusFull)
                .overlay(
                    RoundedRectangle(cornerRadius: WanderSpacing.radiusFull)
                        .stroke(isSelected ? Color.clear : WanderColors.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Photo Grid Item
struct PhotoGridItem: View {
    let asset: PHAsset
    let isSelected: Bool
    let selectionOrder: Int?
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Thumbnail
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(WanderColors.surface)
                    }

                    // Selection Overlay
                    if isSelected {
                        Rectangle()
                            .fill(WanderColors.primary.opacity(0.3))

                        // Selection Badge
                        ZStack {
                            Circle()
                                .fill(WanderColors.primary)
                                .frame(width: 24, height: 24)

                            if let order = selectionOrder {
                                Text("\(order)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(6)
                    }

                    // GPS Indicator
                    if asset.location != nil {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                Spacer()
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
}

// MARK: - Date Range Picker Sheet
struct DateRangePickerSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space5) {
                VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                    Text("시작일")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)

                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                    Text("종료일")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)

                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                Spacer()

                Button(action: {
                    onApply()
                    dismiss()
                }) {
                    Text("적용")
                        .font(WanderTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: WanderSpacing.buttonHeight)
                        .background(WanderColors.primary)
                        .cornerRadius(WanderSpacing.radiusLarge)
                }
            }
            .padding(WanderSpacing.screenMargin)
            .navigationTitle("기간 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Photo Frame Preference Key
struct PhotoFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Draggable Photo Grid Item
struct DraggablePhotoGridItem: View {
    let asset: PHAsset
    let isSelected: Bool
    let selectionOrder: Int?
    let isDragging: Bool
    let action: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    // Thumbnail
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(WanderColors.surface)
                    }

                    // Selection Overlay
                    if isSelected {
                        Rectangle()
                            .fill(WanderColors.primary.opacity(0.3))

                        // Selection Badge
                        ZStack {
                            Circle()
                                .fill(WanderColors.primary)
                                .frame(width: 24, height: 24)

                            if let order = selectionOrder {
                                Text("\(order)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(6)
                    }

                    // GPS Indicator
                    if asset.location != nil {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                Spacer()
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isDragging) // Disable tap during drag
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            self.thumbnail = image
        }
    }
}

#Preview {
    PhotoSelectionView()
}
