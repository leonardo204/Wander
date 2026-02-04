import SwiftUI
import Photos
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoPickerWithAnalysis")

/// 선택된 사진을 감싸는 Identifiable 래퍼 (fullScreenCover(item:) 용)
struct SelectedPhotosWrapper: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
}

/// CustomPhotoPickerView + AnalyzingView를 연결하는 컨테이너
/// HomeView에서 직접 사용
struct PhotoPickerWithAnalysis: View {
    // MARK: - Properties

    /// 분석 완료 후 저장된 기록 콜백
    var onSaveComplete: ((TravelRecord) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 선택된 사진 (item 기반 fullScreenCover용)
    @State private var selectedPhotosWrapper: SelectedPhotosWrapper?

    // MARK: - Body

    var body: some View {
        CustomPhotoPickerView(
            onSelect: { assets in
                logger.info("📷 [PhotoPickerWithAnalysis] 사진 선택됨: \(assets.count)장")
                if !assets.isEmpty {
                    // item 기반으로 설정 - 이 시점에 정확한 assets 전달
                    selectedPhotosWrapper = SelectedPhotosWrapper(assets: assets)
                }
            },
            onCancel: {
                logger.info("📷 [PhotoPickerWithAnalysis] 취소됨")
                dismiss()
            }
        )
        .fullScreenCover(item: $selectedPhotosWrapper) { wrapper in
            AnalyzingViewWrapper(
                selectedAssets: wrapper.assets,
                onSaveComplete: { savedRecord in
                    logger.info("📷 [PhotoPickerWithAnalysis] 저장 완료: \(savedRecord.title)")
                    onSaveComplete?(savedRecord)
                    dismiss()
                }
            )
        }
    }
}

// MARK: - AnalyzingViewWrapper

/// PHAsset 배열로 직접 분석을 시작하는 래퍼
/// PhotoSelectionViewModel을 내부에서 생성하여 AnalyzingView에 전달
struct AnalyzingViewWrapper: View {
    let selectedAssets: [PHAsset]
    var onSaveComplete: ((TravelRecord) -> Void)?

    @StateObject private var viewModel: PhotoSelectionViewModel

    init(selectedAssets: [PHAsset], onSaveComplete: ((TravelRecord) -> Void)?) {
        self.selectedAssets = selectedAssets
        self.onSaveComplete = onSaveComplete

        let vm = PhotoSelectionViewModel()
        vm.selectedAssets = selectedAssets
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        AnalyzingView(viewModel: viewModel, onSaveComplete: onSaveComplete)
    }
}

// MARK: - Preview

#Preview {
    PhotoPickerWithAnalysis()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
