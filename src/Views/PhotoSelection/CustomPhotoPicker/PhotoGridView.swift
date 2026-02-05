import SwiftUI
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoGridView")

// MARK: - SwiftUI Wrapper

/// UICollectionView 기반 사진 그리드 뷰
/// - UIPanGestureRecognizer로 정확한 swipe 선택 지원
/// - indexPathForItem(at:)으로 스크롤 위치 자동 반영
struct PhotoGridView: View {
    let assets: [PHAsset]
    @Binding var selectedAssets: Set<String>
    let thumbnailSize: CGSize

    var body: some View {
        PhotoGridCollectionView(
            assets: assets,
            selectedAssets: $selectedAssets,
            thumbnailSize: thumbnailSize
        )
    }
}

// MARK: - UIViewRepresentable

struct PhotoGridCollectionView: UIViewRepresentable {
    let assets: [PHAsset]
    @Binding var selectedAssets: Set<String>
    let thumbnailSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor(WanderColors.background)
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.register(PhotoGridCell.self, forCellWithReuseIdentifier: PhotoGridCell.identifier)

        // Swipe 선택용 Pan Gesture
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        panGesture.delegate = context.coordinator
        // 기본 스크롤 제스처가 실패해야 pan 제스처 활성화
        collectionView.panGestureRecognizer.require(toFail: panGesture)
        collectionView.addGestureRecognizer(panGesture)

        context.coordinator.collectionView = collectionView

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.assets = assets
        context.coordinator.selectedAssets = selectedAssets

        // 레이아웃 업데이트
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let width = collectionView.bounds.width
            let itemWidth = (width - 6) / 4  // 4열, 3개의 간격
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        }

        collectionView.reloadData()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate {
        var parent: PhotoGridCollectionView
        var assets: [PHAsset] = []
        var selectedAssets: Set<String> = []
        weak var collectionView: UICollectionView?

        // 드래그 선택 상태
        private var isDragging = false
        private var dragStartIndexPath: IndexPath?
        private var dragSelectionMode: Bool = true  // true: 선택, false: 해제
        private var lastProcessedIndexPath: IndexPath?

        private let imageManager = PHCachingImageManager()
        private var thumbnailCache = NSCache<NSString, UIImage>()

        init(_ parent: PhotoGridCollectionView) {
            self.parent = parent
            self.assets = parent.assets
            self.selectedAssets = parent.selectedAssets
            thumbnailCache.countLimit = 500
        }

        // MARK: - UICollectionViewDataSource

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return assets.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridCell.identifier, for: indexPath) as! PhotoGridCell
            let asset = assets[indexPath.item]
            let isSelected = selectedAssets.contains(asset.localIdentifier)

            cell.configure(isSelected: isSelected)
            loadThumbnail(for: asset, into: cell)

            return cell
        }

        // MARK: - UICollectionViewDelegate

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let asset = assets[indexPath.item]
            let id = asset.localIdentifier

            if selectedAssets.contains(id) {
                selectedAssets.remove(id)
                parent.selectedAssets.remove(id)
                logger.info("📷 [PhotoGridView] 선택 해제: \(id.prefix(8))...")
            } else {
                selectedAssets.insert(id)
                parent.selectedAssets.insert(id)
                logger.info("📷 [PhotoGridView] 선택: \(id.prefix(8))...")
            }

            collectionView.reloadItems(at: [indexPath])
        }

        // MARK: - UICollectionViewDelegateFlowLayout

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let width = collectionView.bounds.width
            let itemWidth = (width - 6) / 4
            return CGSize(width: itemWidth, height: itemWidth)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            return UIEdgeInsets(top: 0, left: 0, bottom: 80, right: 0)  // 하단 버튼 공간
        }

        // MARK: - Pan Gesture Handler

        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let collectionView = collectionView else { return }

            let location = gesture.location(in: collectionView)

            switch gesture.state {
            case .began:
                // 드래그 시작
                isDragging = true
                dragStartIndexPath = collectionView.indexPathForItem(at: location)
                lastProcessedIndexPath = nil

                // 시작 위치의 선택 상태로 모드 결정
                if let startIndexPath = dragStartIndexPath {
                    let asset = assets[startIndexPath.item]
                    dragSelectionMode = !selectedAssets.contains(asset.localIdentifier)
                    processSelection(at: startIndexPath)
                }
                logger.info("📷 [PhotoGridView] 드래그 시작 - 모드: \(self.dragSelectionMode ? "선택" : "해제")")

            case .changed:
                // 드래그 중 - 현재 위치의 셀 선택/해제
                if let currentIndexPath = collectionView.indexPathForItem(at: location) {
                    if currentIndexPath != lastProcessedIndexPath {
                        processSelection(at: currentIndexPath)
                        lastProcessedIndexPath = currentIndexPath
                    }
                }

            case .ended, .cancelled, .failed:
                // 드래그 종료
                isDragging = false
                dragStartIndexPath = nil
                lastProcessedIndexPath = nil
                logger.info("📷 [PhotoGridView] 드래그 완료: \(self.selectedAssets.count)장 선택됨")

            default:
                break
            }
        }

        private func processSelection(at indexPath: IndexPath) {
            guard indexPath.item < assets.count else { return }

            let asset = assets[indexPath.item]
            let id = asset.localIdentifier

            if dragSelectionMode {
                // 선택 모드
                if !selectedAssets.contains(id) {
                    selectedAssets.insert(id)
                    parent.selectedAssets.insert(id)
                }
            } else {
                // 해제 모드
                if selectedAssets.contains(id) {
                    selectedAssets.remove(id)
                    parent.selectedAssets.remove(id)
                }
            }

            collectionView?.reloadItems(at: [indexPath])
        }

        // MARK: - UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
                  let collectionView = collectionView else {
                return true
            }

            let velocity = panGesture.velocity(in: collectionView)
            // 수평 속도가 수직 속도보다 클 때만 swipe 선택 활성화
            return abs(velocity.x) > abs(velocity.y)
        }

        // MARK: - Thumbnail Loading

        private func loadThumbnail(for asset: PHAsset, into cell: PhotoGridCell) {
            let cacheKey = NSString(string: asset.localIdentifier)

            // 캐시 확인
            if let cached = thumbnailCache.object(forKey: cacheKey) {
                cell.setImage(cached)
                return
            }

            // 새로 로드
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let targetSize = CGSize(width: 200, height: 200)

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self, weak cell] image, info in
                guard let image = image else { return }

                self?.thumbnailCache.setObject(image, forKey: cacheKey)

                DispatchQueue.main.async {
                    cell?.setImage(image)
                }
            }
        }
    }
}

// MARK: - Photo Grid Cell

class PhotoGridCell: UICollectionViewCell {
    static let identifier = "PhotoGridCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor(WanderColors.surface)
        return iv
    }()

    private let checkmarkView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(WanderColors.primary)
        view.layer.cornerRadius = 12
        return view
    }()

    private let checkmarkIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark")
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emptyCircleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        return view
    }()

    private let selectionBorder: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor(WanderColors.primary).cgColor
        view.isHidden = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(imageView)
        contentView.addSubview(selectionBorder)
        contentView.addSubview(emptyCircleView)
        contentView.addSubview(checkmarkView)
        checkmarkView.addSubview(checkmarkIcon)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        selectionBorder.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkIcon.translatesAutoresizingMaskIntoConstraints = false
        emptyCircleView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            selectionBorder.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionBorder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionBorder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionBorder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24),

            checkmarkIcon.centerXAnchor.constraint(equalTo: checkmarkView.centerXAnchor),
            checkmarkIcon.centerYAnchor.constraint(equalTo: checkmarkView.centerYAnchor),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 12),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 12),

            emptyCircleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            emptyCircleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            emptyCircleView.widthAnchor.constraint(equalToConstant: 24),
            emptyCircleView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    func configure(isSelected: Bool) {
        checkmarkView.isHidden = !isSelected
        emptyCircleView.isHidden = isSelected
        selectionBorder.isHidden = !isSelected
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        configure(isSelected: false)
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
