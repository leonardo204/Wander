import SwiftUI
import Photos
import DKImagePickerController
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "DKImagePicker")

/// DKImagePickerController를 SwiftUI에서 사용하기 위한 UIViewControllerRepresentable 래퍼
struct DKImagePickerRepresentable: UIViewControllerRepresentable {
    // MARK: - Properties

    /// 날짜 필터링 범위 (nil이면 전체)
    var startDate: Date?
    var endDate: Date?

    /// 선택 완료 콜백 - PHAsset 배열 전달
    var onSelect: (([PHAsset]) -> Void)?

    /// 취소 콜백
    var onCancel: (() -> Void)?

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> DKImagePickerController {
        // 날짜 범위 필터링을 위한 DKImageGroupDataManager 생성
        var customDataManager: DKImageGroupDataManager?

        if let start = startDate, let end = endDate {
            logger.info("📷 [DKImagePicker] 날짜 범위 필터 적용: \(start) ~ \(end)")

            let configuration = DKImageGroupDataManagerConfiguration()

            // PHFetchOptions 설정
            let fetchOptions = PHFetchOptions()
            // 날짜 범위 + 이미지 타입 predicate 설정
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@ AND mediaType == %d",
                start as NSDate,
                end as NSDate,
                PHAssetMediaType.image.rawValue
            )
            // 최신순 정렬
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            configuration.assetFetchOptions = fetchOptions
            configuration.assetGroupTypes = [.smartAlbumUserLibrary]  // 모든 사진 앨범만

            customDataManager = DKImageGroupDataManager(configuration: configuration)
        }

        // 커스텀 dataManager를 사용하여 picker 초기화
        let picker = DKImagePickerController(groupDataManager: customDataManager)

        // 기본 설정
        picker.assetType = .allPhotos
        picker.allowMultipleTypes = false
        picker.showsEmptyAlbums = false
        picker.maxSelectableCount = 0  // 무제한
        picker.allowSwipeToSelect = true
        picker.sourceType = .photo  // 사진 라이브러리만
        picker.showsCancelButton = false  // 기본 취소 버튼 숨김 (커스텀 사용)

        // 선택 완료 콜백
        picker.didSelectAssets = { [onSelect] assets in
            logger.info("📷 [DKImagePicker] 선택 완료: \(assets.count)장")

            // DKAsset -> PHAsset 변환
            let phAssets = assets.compactMap { dkAsset -> PHAsset? in
                return dkAsset.originalAsset
            }

            logger.info("📷 [DKImagePicker] PHAsset 변환: \(phAssets.count)장")
            onSelect?(phAssets)
        }

        // 취소 콜백
        picker.didCancel = { [onCancel] in
            logger.info("📷 [DKImagePicker] 취소됨")
            onCancel?()
        }

        // UI 커스터마이징 - 커스텀 델리게이트 적용
        let uiDelegate = CustomPickerUIDelegate()
        picker.UIDelegate = uiDelegate

        return picker
    }

    func updateUIViewController(_ uiViewController: DKImagePickerController, context: Context) {
        // DKImagePickerController는 런타임 업데이트를 제한적으로 지원
        // 필요시 picker를 다시 생성해야 함
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        // 상태 관리용
    }
}

// MARK: - 커스텀 UIDelegate

/// DKImagePickerController UI 커스터마이징
class CustomPickerUIDelegate: DKImagePickerControllerBaseUIDelegate {

    override func prepareLayout(_ imagePickerController: DKImagePickerController, vc: UIViewController) {
        super.prepareLayout(imagePickerController, vc: vc)

        // 좌측에 취소 버튼 추가
        let cancelButton = UIBarButtonItem(
            title: "취소",
            style: .plain,
            target: self,
            action: #selector(handleCancel)
        )
        cancelButton.tintColor = UIColor(WanderColors.textSecondary)
        vc.navigationItem.leftBarButtonItem = cancelButton

        // 네비게이션 바 타이틀
        vc.navigationItem.title = "사진 선택"
    }

    @objc private func handleCancel() {
        imagePickerController?.dismiss()
    }

    override func updateDoneButtonTitle(_ button: UIButton) {
        let selectedCount = imagePickerController?.selectedAssets.count ?? 0
        if selectedCount > 0 {
            button.setTitle("선택(\(selectedCount))", for: .normal)
        } else {
            button.setTitle("선택", for: .normal)
        }
        button.setTitleColor(UIColor(WanderColors.primary), for: .normal)
    }
}

// MARK: - Preview

#Preview {
    DKImagePickerRepresentable(
        startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        endDate: Date(),
        onSelect: { assets in
            print("선택된 사진: \(assets.count)장")
        },
        onCancel: {
            print("취소됨")
        }
    )
}
