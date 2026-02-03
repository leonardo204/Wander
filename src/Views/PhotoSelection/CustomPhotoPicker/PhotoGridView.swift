import SwiftUI
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoGridView")

/// 사진 그리드 뷰 - LazyVGrid 기반, Swipe 선택 지원
struct PhotoGridView: View {
    // MARK: - Properties

    let assets: [PHAsset]
    @Binding var selectedAssets: Set<String>  // PHAsset.localIdentifier 저장
    let thumbnailSize: CGSize

    @StateObject private var thumbnailLoader = ThumbnailLoader()

    // Swipe 선택용 상태
    @State private var isDragging = false
    @State private var dragStartIndex: Int?
    @State private var dragCurrentIndex: Int?
    @State private var dragSelectionMode: Bool = true  // true: 선택 모드, false: 해제 모드

    // 그리드 레이아웃 (4열)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 4)
    private let spacing: CGFloat = 2

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let itemSize = (geometry.size.width - spacing * 3) / 4

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        PhotoThumbnailView(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset.localIdentifier),
                            size: CGSize(width: itemSize, height: itemSize),
                            thumbnailLoader: thumbnailLoader
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(asset)
                        }
                        .background(
                            GeometryReader { itemGeometry in
                                Color.clear
                                    .preference(
                                        key: GridPhotoFramePreferenceKey.self,
                                        value: [index: itemGeometry.frame(in: .named("photoGrid"))]
                                    )
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            .coordinateSpace(name: "photoGrid")
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        handleDragChanged(value: value, itemSize: itemSize, gridWidth: geometry.size.width)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
            .onPreferenceChange(GridPhotoFramePreferenceKey.self) { frames in
                // 프레임 정보 저장 (필요시 사용)
            }
        }
    }

    // MARK: - Selection Logic

    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedAssets.contains(id) {
            selectedAssets.remove(id)
            logger.info("📷 [PhotoGridView] 선택 해제: \(id.prefix(8))...")
        } else {
            selectedAssets.insert(id)
            logger.info("📷 [PhotoGridView] 선택: \(id.prefix(8))...")
        }
    }

    // MARK: - Drag Selection

    private func handleDragChanged(value: DragGesture.Value, itemSize: CGFloat, gridWidth: CGFloat) {
        let location = value.location
        let startLocation = value.startLocation

        // 현재 드래그 위치의 인덱스 계산
        let currentIndex = indexAt(location: location, itemSize: itemSize, gridWidth: gridWidth)

        // 드래그 시작 시
        if !isDragging {
            isDragging = true
            dragStartIndex = indexAt(location: startLocation, itemSize: itemSize, gridWidth: gridWidth)

            // 시작 위치의 선택 상태에 따라 모드 결정
            if let startIdx = dragStartIndex, startIdx < assets.count {
                let startAsset = assets[startIdx]
                dragSelectionMode = !selectedAssets.contains(startAsset.localIdentifier)
            }
        }

        // 유효한 인덱스인 경우 선택/해제
        if let currentIdx = currentIndex, currentIdx < assets.count {
            if dragCurrentIndex != currentIdx {
                dragCurrentIndex = currentIdx
                let asset = assets[currentIdx]
                let id = asset.localIdentifier

                if dragSelectionMode {
                    if !selectedAssets.contains(id) {
                        selectedAssets.insert(id)
                    }
                } else {
                    if selectedAssets.contains(id) {
                        selectedAssets.remove(id)
                    }
                }
            }
        }
    }

    private func handleDragEnded() {
        isDragging = false
        dragStartIndex = nil
        dragCurrentIndex = nil
        logger.info("📷 [PhotoGridView] 드래그 선택 완료: \(selectedAssets.count)장")
    }

    /// 화면 좌표에서 그리드 인덱스 계산
    private func indexAt(location: CGPoint, itemSize: CGFloat, gridWidth: CGFloat) -> Int? {
        guard location.x >= 0, location.y >= 0 else { return nil }

        let adjustedItemSize = itemSize + spacing
        let col = Int(location.x / adjustedItemSize)
        let row = Int(location.y / adjustedItemSize)

        guard col >= 0, col < 4, row >= 0 else { return nil }

        let index = row * 4 + col
        return index < assets.count ? index : nil
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let size: CGSize
    @ObservedObject var thumbnailLoader: ThumbnailLoader

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 썸네일 이미지
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(WanderColors.surface)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .tint(WanderColors.textTertiary)
                    )
            }

            // 선택 표시
            if isSelected {
                // 선택된 상태 - 체크마크
                Circle()
                    .fill(WanderColors.primary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .padding(6)

                // 선택 테두리
                RoundedRectangle(cornerRadius: 0)
                    .stroke(WanderColors.primary, lineWidth: 3)
                    .frame(width: size.width, height: size.height)
            } else {
                // 미선택 상태 - 빈 원
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
                    .padding(6)
            }
        }
        .frame(width: size.width, height: size.height)
        .task(id: asset.localIdentifier) {
            thumbnail = await thumbnailLoader.loadThumbnail(for: asset, targetSize: CGSize(width: size.width * 2, height: size.height * 2))
        }
    }
}

// MARK: - Thumbnail Loader

/// 썸네일 로딩 및 캐싱 관리
@MainActor
class ThumbnailLoader: ObservableObject {
    private let imageManager = PHCachingImageManager()
    private var cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 500  // 최대 500개 캐시
    }

    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let cacheKey = NSString(string: asset.localIdentifier)

        // 캐시 확인
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // 새로 로드
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                if let image = image {
                    self?.cache.setObject(image, forKey: cacheKey)
                }
                // 최종 이미지만 반환 (degraded가 아닌 경우)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Preference Key

struct GridPhotoFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Preview

#Preview {
    PhotoGridView(
        assets: [],
        selectedAssets: .constant([]),
        thumbnailSize: CGSize(width: 100, height: 100)
    )
}
