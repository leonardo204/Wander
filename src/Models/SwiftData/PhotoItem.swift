import Foundation
import SwiftData

@Model
final class PhotoItem {
    var id: UUID
    var assetIdentifier: String?  // 공유받은 사진은 nil
    var capturedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var hasGPS: Bool
    var order: Int

    /// 공유받은 사진의 로컬 파일 경로 (Documents 디렉토리)
    var localFilePath: String?

    var place: Place?

    init(
        assetIdentifier: String?,
        capturedAt: Date?,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.hasGPS = latitude != nil && longitude != nil
        self.order = 0
        self.localFilePath = nil
    }

    /// 사진 소스 확인 (PHAsset 또는 로컬 파일)
    var isFromPhotoLibrary: Bool {
        assetIdentifier != nil
    }

    /// 사진 소스 확인 (공유받은 사진)
    var isSharedPhoto: Bool {
        localFilePath != nil && assetIdentifier == nil
    }
}
