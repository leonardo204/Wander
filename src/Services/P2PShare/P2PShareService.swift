import Foundation
import SwiftUI
import SwiftData
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "P2PShareService")

// MARK: - P2P Share Service

/// P2P 기록 공유 서비스
@MainActor
final class P2PShareService: ObservableObject {

    static let shared = P2PShareService()

    // MARK: - Dependencies

    private let cloudKit = CloudKitManager.shared
    private let encryption = EncryptionService.shared

    // MARK: - Published

    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var progressMessage: String = ""

    // MARK: - Init

    private init() {
        logger.debug("🔗 P2PShareService 초기화")
    }

    // MARK: - Create Share Link

    /// 공유 링크 생성
    /// - Parameters:
    ///   - record: 공유할 여행 기록
    ///   - options: 공유 옵션
    /// - Returns: 공유 결과 (URL 포함)
    func createShareLink(
        for record: TravelRecord,
        options: ShareOptions
    ) async throws -> P2PShareResult {
        logger.info("🔗 공유 링크 생성 시작: \(record.title)")

        isProcessing = true
        progress = 0
        progressMessage = "공유 준비 중..."

        defer {
            isProcessing = false
            progress = 0
            progressMessage = ""
        }

        // 1. SharePackage 생성
        progressMessage = "데이터 변환 중..."
        progress = 0.1

        let shareID = UUID()
        let sharePackage = try await createSharePackage(
            from: record,
            shareID: shareID,
            options: options
        )

        progress = 0.3

        // 2. 사진 준비
        progressMessage = "사진 처리 중..."
        let photoURLs = try await preparePhotos(
            from: record,
            quality: options.photoQuality
        )

        progress = 0.5

        // 3. 암호화
        progressMessage = "암호화 중..."
        let encryptionKey = encryption.generateEncryptionKey()
        let encryptedData = try encryption.encrypt(sharePackage, key: encryptionKey)

        progress = 0.7

        // 4. CloudKit 업로드
        progressMessage = "업로드 중..."
        _ = try await cloudKit.uploadSharePackage(
            shareID: shareID,
            encryptedData: encryptedData,
            photoAssets: photoURLs,
            expiresAt: options.linkExpiration.expirationDate
        )

        progress = 0.9

        // 5. 공유 URL 생성 (Custom URL Scheme 사용 - 도메인 불필요)
        let encodedKey = encryption.encodeKeyForURL(encryptionKey)
        let deepLink = ShareDeepLink(shareID: shareID.uuidString, encryptionKey: encodedKey)

        // Custom URL Scheme 우선 사용 (wander://...)
        guard let shareURL = deepLink.customSchemeURL ?? deepLink.universalLinkURL else {
            throw P2PShareError.serializationFailed
        }

        // 6. 임시 파일 정리
        cleanupTempFiles(photoURLs)

        progress = 1.0
        progressMessage = "완료!"

        logger.info("✅ 공유 링크 생성 완료: \(shareURL.absoluteString)")

        return P2PShareResult(
            shareID: shareID,
            shareURL: shareURL,
            expiresAt: options.linkExpiration.expirationDate,
            photoCount: photoURLs.count,
            totalSize: Int64(encryptedData.count)
        )
    }

    // MARK: - Receive Share

    /// 공유 링크에서 미리보기 정보 가져오기
    /// - Parameter url: 공유 URL
    /// - Returns: 공유 미리보기 정보
    func receiveSharePreview(from url: URL) async throws -> SharePreview {
        logger.info("🔗 공유 미리보기 로드: \(url.absoluteString)")

        // 1. URL 파싱
        guard let deepLink = ShareDeepLink.parse(from: url) else {
            logger.error("❌ 유효하지 않은 공유 URL")
            throw P2PShareError.invalidShareLink
        }

        // 2. CloudKit에서 다운로드
        let (encryptedData, photoURLs, expiresAt) = try await cloudKit.downloadSharePackage(
            shareID: deepLink.shareID
        )

        // 3. 복호화
        let encryptionKey = try encryption.decodeKeyFromURL(deepLink.encryptionKey)
        let sharePackage = try encryption.decrypt(
            SharePackage.self,
            from: encryptedData,
            key: encryptionKey
        )

        // 4. 썸네일 추출 (첫 번째 사진)
        var thumbnailData: Data?
        if let firstPhotoURL = photoURLs.first {
            thumbnailData = try? Data(contentsOf: firstPhotoURL)
        }

        // 5. 장소 수 계산
        let placeCount = sharePackage.record.days.reduce(0) { $0 + $1.places.count }

        return SharePreview(
            shareID: UUID(uuidString: deepLink.shareID) ?? UUID(),
            title: sharePackage.record.title,
            startDate: sharePackage.record.startDate,
            endDate: sharePackage.record.endDate,
            placeCount: placeCount,
            totalDistance: sharePackage.record.totalDistance,
            photoCount: sharePackage.photoReferences.count,
            senderName: sharePackage.senderName,
            expiresAt: expiresAt,
            thumbnailData: thumbnailData
        )
    }

    // MARK: - Cleanup Expired Records

    /// 만료된 공유 기록 정리
    /// - Parameter modelContext: SwiftData 컨텍스트
    /// - Returns: 삭제된 기록 수
    @discardableResult
    func cleanupExpiredSharedRecords(modelContext: ModelContext) async -> Int {
        logger.info("🧹 [cleanupExpiredSharedRecords] 만료된 공유 기록 정리 시작")

        do {
            // 만료된 공유 기록 조회
            let now = Date()
            let descriptor = FetchDescriptor<TravelRecord>(
                predicate: #Predicate<TravelRecord> {
                    $0.isShared == true && $0.shareExpiresAt != nil && $0.shareExpiresAt! < now
                }
            )

            let expiredRecords = try modelContext.fetch(descriptor)

            guard !expiredRecords.isEmpty else {
                logger.info("🧹 만료된 공유 기록 없음")
                return 0
            }

            logger.info("🧹 만료된 공유 기록 \(expiredRecords.count)개 발견")

            for record in expiredRecords {
                logger.info("🧹 삭제: \(record.title) (만료일: \(record.shareExpiresAt?.formatted() ?? "unknown"))")

                // 로컬 사진 파일 삭제
                if let shareID = record.originalShareID?.uuidString {
                    deleteLocalPhotos(shareID: shareID)
                }

                // SwiftData에서 삭제
                modelContext.delete(record)
            }

            try modelContext.save()
            logger.info("🧹 만료된 공유 기록 \(expiredRecords.count)개 삭제 완료")

            return expiredRecords.count

        } catch {
            logger.error("❌ 만료된 공유 기록 정리 실패: \(error.localizedDescription)")
            return 0
        }
    }

    /// 로컬 사진 파일 삭제 (내부용)
    private func deleteLocalPhotos(shareID: String) {
        deleteLocalPhotosSync(shareID: shareID)
    }

    /// 로컬 사진 파일 삭제 (동기, 외부 호출용)
    /// - Parameter shareID: 공유 ID
    func deleteLocalPhotosSync(shareID: String) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let shareDir = documentsDir.appendingPathComponent("SharedRecords/\(shareID)")

        do {
            if FileManager.default.fileExists(atPath: shareDir.path) {
                try FileManager.default.removeItem(at: shareDir)
                logger.info("🧹 로컬 사진 폴더 삭제: \(shareDir.lastPathComponent)")
            }
        } catch {
            logger.error("❌ 로컬 사진 폴더 삭제 실패: \(error.localizedDescription)")
        }
    }

    /// 공유 기록 저장
    /// - Parameters:
    ///   - url: 공유 URL
    ///   - modelContext: SwiftData 컨텍스트
    /// - Returns: 저장된 TravelRecord
    func saveSharedRecord(
        from url: URL,
        modelContext: ModelContext
    ) async throws -> TravelRecord {
        logger.info("🔗 공유 기록 저장 시작")

        isProcessing = true
        progress = 0
        progressMessage = "다운로드 중..."

        defer {
            isProcessing = false
            progress = 0
            progressMessage = ""
        }

        // 1. URL 파싱
        guard let deepLink = ShareDeepLink.parse(from: url) else {
            throw P2PShareError.invalidShareLink
        }

        // 2. 중복 체크
        let shareIDString = deepLink.shareID
        if let existingRecord = try? await checkDuplicateShare(
            shareID: shareIDString,
            modelContext: modelContext
        ) {
            logger.warning("⚠️ 이미 저장된 기록: \(existingRecord.title)")
            throw P2PShareError.duplicateShare
        }

        progress = 0.2

        // 3. CloudKit에서 다운로드
        let (encryptedData, photoURLs, _) = try await cloudKit.downloadSharePackage(
            shareID: deepLink.shareID
        )

        progress = 0.4

        // 4. 복호화
        progressMessage = "복호화 중..."
        let encryptionKey = try encryption.decodeKeyFromURL(deepLink.encryptionKey)
        let sharePackage = try encryption.decrypt(
            SharePackage.self,
            from: encryptedData,
            key: encryptionKey
        )

        // 복호화 결과 로깅
        logger.info("📦 [saveSharedRecord] 복호화 완료")
        logger.info("📦 - 제목: \(sharePackage.record.title)")
        logger.info("📦 - days 수: \(sharePackage.record.days.count)")
        logger.info("📦 - photoReferences 수: \(sharePackage.photoReferences.count)")
        for (dayIndex, day) in sharePackage.record.days.enumerated() {
            logger.info("📦 - Day \(dayIndex + 1): places 수 = \(day.places.count)")
            for (placeIndex, place) in day.places.enumerated() {
                logger.info("📦   - Place \(placeIndex + 1): '\(place.name)', photoIndices = \(place.photoIndices)")
            }
        }

        progress = 0.6

        // 5. 사진 로컬 저장
        progressMessage = "사진 저장 중..."
        let savedPhotoURLs = try await savePhotosLocally(
            from: photoURLs,
            shareID: shareIDString
        )

        progress = 0.8

        // 6. TravelRecord로 변환 및 저장
        progressMessage = "기록 저장 중..."
        let travelRecord = try await convertToTravelRecord(
            from: sharePackage,
            photoURLs: savedPhotoURLs,
            shareID: shareIDString,
            modelContext: modelContext
        )

        progress = 1.0

        logger.info("✅ 공유 기록 저장 완료: \(travelRecord.title)")

        return travelRecord
    }

    // MARK: - Private Helpers

    /// TravelRecord를 SharePackage로 변환
    private func createSharePackage(
        from record: TravelRecord,
        shareID: UUID,
        options: ShareOptions
    ) async throws -> SharePackage {
        logger.info("📦 [createSharePackage] 패키지 생성 시작")
        logger.info("📦 - 원본 record.days.count: \(record.days.count)")

        var photoReferences: [PhotoReference] = []
        var photoIndex = 0

        // Days 변환 (정렬 보장)
        let sortedDays = record.days.sorted { $0.dayNumber < $1.dayNumber }
        logger.info("📦 - 정렬된 days 수: \(sortedDays.count)")

        let sharedDays: [SharedTravelDay] = sortedDays.map { day in
            let sortedPlaces = day.places.sorted { $0.order < $1.order }
            logger.info("📦 - Day \(day.dayNumber): places 수 = \(sortedPlaces.count)")

            let sharedPlaces: [SharedPlace] = sortedPlaces.map { place in
                let sortedPhotos = place.photos.sorted { $0.order < $1.order }
                logger.info("📦   - Place '\(place.name)': photos 수 = \(sortedPhotos.count)")

                // 각 장소의 사진 인덱스 수집
                let placePhotoIndices: [Int] = sortedPhotos.compactMap { photo in
                    let index = photoIndex
                    photoReferences.append(PhotoReference(
                        index: index,
                        filename: "photo_\(index).jpg",
                        capturedAt: photo.capturedAt,
                        latitude: photo.latitude,
                        longitude: photo.longitude
                    ))
                    photoIndex += 1
                    return index
                }

                logger.info("📦   - Place '\(place.name)': photoIndices = \(placePhotoIndices)")

                return SharedPlace(
                    name: place.name,
                    address: place.address,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    startTime: place.startTime,
                    endTime: place.endTime,
                    activityLabel: place.activityLabel,
                    photoIndices: placePhotoIndices
                )
            }

            return SharedTravelDay(
                date: day.date,
                dayNumber: day.dayNumber,
                places: sharedPlaces
            )
        }

        let sharedRecord = SharedTravelRecord(
            title: record.title,
            startDate: record.startDate,
            endDate: record.endDate,
            totalDistance: record.totalDistance,
            aiStory: record.aiStory,
            days: sharedDays
        )

        logger.info("📦 [createSharePackage] 패키지 생성 완료")
        logger.info("📦 - 총 days: \(sharedDays.count)")
        logger.info("📦 - 총 photoReferences: \(photoReferences.count)")

        return SharePackage(
            shareID: shareID,
            expiresAt: options.linkExpiration.expirationDate,
            senderName: options.senderName,
            record: sharedRecord,
            photoReferences: photoReferences
        )
    }

    /// 사진 준비 (리사이즈 및 임시 파일 저장)
    private func preparePhotos(
        from record: TravelRecord,
        quality: PhotoQuality
    ) async throws -> [URL] {
        var photoURLs: [URL] = []
        let tempDir = FileManager.default.temporaryDirectory

        for day in record.days {
            for place in day.places {
                for photo in place.photos {
                    guard let assetIdentifier = photo.assetIdentifier else { continue }

                    // PHAsset에서 이미지 로드
                    if let imageData = await loadImageData(
                        assetIdentifier: assetIdentifier,
                        maxPixelSize: quality.maxPixelSize
                    ) {
                        let filename = "share_photo_\(photoURLs.count).jpg"
                        let fileURL = tempDir.appendingPathComponent(filename)

                        do {
                            try imageData.write(to: fileURL)
                            photoURLs.append(fileURL)
                        } catch {
                            logger.error("❌ 사진 임시 저장 실패: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        return photoURLs
    }

    /// PHAsset에서 이미지 데이터 로드
    private func loadImageData(assetIdentifier: String, maxPixelSize: Int?) async -> Data? {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        )

        guard let asset = fetchResult.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            let targetSize: CGSize
            if let maxSize = maxPixelSize {
                targetSize = CGSize(width: maxSize, height: maxSize)
            } else {
                targetSize = PHImageManagerMaximumSize
            }

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard let image = image,
                      let data = image.jpegData(compressionQuality: 0.8) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    /// 사진을 로컬 Documents 디렉토리에 저장
    private func savePhotosLocally(from urls: [URL], shareID: String) async throws -> [URL] {
        logger.info("📸 [savePhotosLocally] 사진 로컬 저장 시작")
        logger.info("📸 - 입력 URL 수: \(urls.count)")

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let shareDir = documentsDir.appendingPathComponent("SharedRecords/\(shareID)")

        logger.info("📸 - 저장 경로: \(shareDir.path)")

        try FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)

        var savedURLs: [URL] = []

        for (index, url) in urls.enumerated() {
            let filename = "photo_\(index).jpg"
            let destURL = shareDir.appendingPathComponent(filename)

            do {
                let data = try Data(contentsOf: url)
                try data.write(to: destURL)
                savedURLs.append(destURL)
                logger.info("📸 - 저장 완료 [\(index)]: \(destURL.lastPathComponent) (\(data.count) bytes)")
            } catch {
                logger.error("❌ 사진 저장 실패 [\(index)]: \(error.localizedDescription)")
            }
        }

        logger.info("📸 [savePhotosLocally] 완료 - 저장된 사진: \(savedURLs.count)개")
        return savedURLs
    }

    /// SharePackage를 TravelRecord로 변환
    private func convertToTravelRecord(
        from package: SharePackage,
        photoURLs: [URL],
        shareID: String,
        modelContext: ModelContext
    ) async throws -> TravelRecord {
        logger.info("📦 [convertToTravelRecord] 변환 시작")
        logger.info("📦 - 패키지 days 수: \(package.record.days.count)")
        logger.info("📦 - 패키지 photoReferences 수: \(package.photoReferences.count)")
        logger.info("📦 - 다운로드된 사진 URL 수: \(photoURLs.count)")

        let record = TravelRecord(
            title: package.record.title,
            startDate: package.record.startDate,
            endDate: package.record.endDate
        )

        record.totalDistance = package.record.totalDistance
        record.aiStory = package.record.aiStory
        record.isShared = true
        record.sharedFrom = package.senderName
        record.sharedAt = Date()
        record.originalShareID = UUID(uuidString: shareID)
        record.shareExpiresAt = package.expiresAt  // 만료일 저장

        if let expiresAt = package.expiresAt {
            logger.info("📦 - 만료일: \(expiresAt.formatted())")
        } else {
            logger.info("📦 - 만료일: 영구 보관")
        }

        // 통계 카운터
        var totalPlaceCount = 0
        var totalPhotoCount = 0

        // Days 변환
        for (dayIndex, sharedDay) in package.record.days.enumerated() {
            logger.info("📦 - Day \(dayIndex + 1): places 수 = \(sharedDay.places.count)")

            let day = TravelDay(date: sharedDay.date, dayNumber: sharedDay.dayNumber)

            for (placeIndex, sharedPlace) in sharedDay.places.enumerated() {
                logger.info("📦   - Place \(placeIndex + 1): \(sharedPlace.name), photoIndices = \(sharedPlace.photoIndices)")

                let coordinate = CLLocationCoordinate2D(
                    latitude: sharedPlace.latitude,
                    longitude: sharedPlace.longitude
                )
                let place = Place(
                    name: sharedPlace.name,
                    address: sharedPlace.address,
                    coordinate: coordinate,
                    startTime: sharedPlace.startTime
                )
                place.endTime = sharedPlace.endTime
                place.activityLabel = sharedPlace.activityLabel
                place.order = placeIndex

                // 사진 연결
                var placePhotoCount = 0
                for photoIndex in sharedPlace.photoIndices {
                    if photoIndex < photoURLs.count {
                        let photoRef = package.photoReferences.first { $0.index == photoIndex }
                        let photoItem = PhotoItem(
                            assetIdentifier: nil,  // 공유 받은 사진은 assetIdentifier 없음
                            capturedAt: photoRef?.capturedAt ?? Date(),
                            latitude: photoRef?.latitude,
                            longitude: photoRef?.longitude
                        )
                        // 로컬 파일 경로 저장
                        photoItem.localFilePath = photoURLs[photoIndex].path
                        photoItem.order = placePhotoCount
                        place.photos.append(photoItem)
                        placePhotoCount += 1
                        totalPhotoCount += 1
                    } else {
                        logger.warning("📦   ⚠️ photoIndex \(photoIndex) out of bounds (photoURLs.count = \(photoURLs.count))")
                    }
                }

                day.places.append(place)
                totalPlaceCount += 1
            }

            record.days.append(day)
        }

        // placeCount, photoCount 업데이트
        record.placeCount = totalPlaceCount
        record.photoCount = totalPhotoCount

        logger.info("📦 [convertToTravelRecord] 변환 완료")
        logger.info("📦 - 생성된 days: \(record.days.count)")
        logger.info("📦 - 생성된 places: \(totalPlaceCount)")
        logger.info("📦 - 생성된 photos: \(totalPhotoCount)")

        modelContext.insert(record)
        try modelContext.save()

        logger.info("📦 [convertToTravelRecord] SwiftData 저장 완료")

        return record
    }

    /// 중복 공유 체크
    private func checkDuplicateShare(
        shareID: String,
        modelContext: ModelContext
    ) async throws -> TravelRecord? {
        guard let uuid = UUID(uuidString: shareID) else { return nil }

        let descriptor = FetchDescriptor<TravelRecord>(
            predicate: #Predicate { $0.originalShareID == uuid }
        )

        let results = try modelContext.fetch(descriptor)
        return results.first
    }

    /// 임시 파일 정리
    private func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
