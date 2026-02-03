import SwiftUI
import Photos
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PhotoPickerWithAnalysis")

/// CustomPhotoPickerView + AnalyzingView를 연결하는 컨테이너
/// HomeView에서 직접 사용
struct PhotoPickerWithAnalysis: View {
    // MARK: - Properties

    /// 분석 완료 후 저장된 기록 콜백
    var onSaveComplete: ((TravelRecord) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 선택된 사진
    @State private var selectedAssets: [PHAsset] = []

    // 분석 화면 표시 여부
    @State private var showAnalysis = false

    // MARK: - Body

    var body: some View {
        CustomPhotoPickerView(
            onSelect: { assets in
                logger.info("📷 [PhotoPickerWithAnalysis] 사진 선택됨: \(assets.count)장")
                selectedAssets = assets
                if !assets.isEmpty {
                    showAnalysis = true
                }
            },
            onCancel: {
                logger.info("📷 [PhotoPickerWithAnalysis] 취소됨")
                dismiss()
            }
        )
        .fullScreenCover(isPresented: $showAnalysis) {
            AnalyzingViewWrapper(
                selectedAssets: selectedAssets,
                onSaveComplete: { savedRecord in
                    logger.info("📷 [PhotoPickerWithAnalysis] 저장 완료: \(savedRecord.title)")
                    onSaveComplete?(savedRecord)
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Preview
// AnalyzingViewWrapper는 DKImagePickerView.swift에 정의됨

#Preview {
    PhotoPickerWithAnalysis()
        .modelContainer(for: TravelRecord.self, inMemory: true)
}
