import Foundation
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "CloudKitManager")

// MARK: - CloudKit Manager

/// CloudKit Public Database 연동 관리
final class CloudKitManager {

    static let shared = CloudKitManager()

    // MARK: - Constants

    private let containerIdentifier = "iCloud.com.zerolive.wander"
    private let recordType = "WanderShare"

    // Field names
    private enum Fields {
        static let shareID = "shareID"
        static let encryptedData = "encryptedData"
        static let photos = "photos"
        static let expiresAt = "expiresAt"
        static let createdAt = "createdAt"
        static let photoCount = "photoCount"
    }

    // MARK: - Properties

    private let container: CKContainer
    private let publicDatabase: CKDatabase

    // MARK: - Init

    private init() {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDatabase = container.publicCloudDatabase
        logger.debug("☁️ CloudKitManager 초기화 (container: \(self.containerIdentifier))")
    }

    // MARK: - Upload

    /// 공유 패키지 업로드
    /// - Parameters:
    ///   - shareID: 공유 ID
    ///   - encryptedData: 암호화된 패키지 데이터
    ///   - photoAssets: 사진 파일 URL 배열
    ///   - expiresAt: 만료 시간 (nil이면 영구)
    /// - Returns: 생성된 CKRecord의 recordID
    func uploadSharePackage(
        shareID: UUID,
        encryptedData: Data,
        photoAssets: [URL],
        expiresAt: Date?
    ) async throws -> CKRecord.ID {
        logger.info("☁️ 공유 패키지 업로드 시작 (shareID: \(shareID.uuidString))")

        // 네트워크 상태 확인
        try await checkNetworkAvailability()

        // CKRecord 생성
        let recordID = CKRecord.ID(recordName: shareID.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        // 필드 설정
        record[Fields.shareID] = shareID.uuidString as CKRecordValue
        record[Fields.encryptedData] = encryptedData as CKRecordValue
        record[Fields.createdAt] = Date() as CKRecordValue
        record[Fields.photoCount] = photoAssets.count as CKRecordValue

        if let expiresAt = expiresAt {
            record[Fields.expiresAt] = expiresAt as CKRecordValue
        }

        // 사진 CKAsset 변환
        if !photoAssets.isEmpty {
            let assets = photoAssets.map { CKAsset(fileURL: $0) }
            record[Fields.photos] = assets as CKRecordValue
        }

        // 업로드
        do {
            let savedRecord = try await publicDatabase.save(record)
            logger.info("✅ 공유 패키지 업로드 완료 (recordID: \(savedRecord.recordID.recordName))")
            return savedRecord.recordID
        } catch {
            logger.error("❌ CloudKit 업로드 실패: \(error.localizedDescription)")
            throw P2PShareError.cloudKitError(error)
        }
    }

    // MARK: - Download

    /// 공유 패키지 다운로드
    /// - Parameter shareID: 공유 ID
    /// - Returns: (암호화된 데이터, 사진 URL 배열, 만료 시간)
    func downloadSharePackage(shareID: String) async throws -> (Data, [URL], Date?) {
        logger.info("☁️ 공유 패키지 다운로드 시작 (shareID: \(shareID))")

        // 네트워크 상태 확인
        try await checkNetworkAvailability()

        // Record 조회
        let recordID = CKRecord.ID(recordName: shareID)

        do {
            let record = try await publicDatabase.record(for: recordID)

            // 만료 확인
            if let expiresAt = record[Fields.expiresAt] as? Date {
                if expiresAt < Date() {
                    logger.warning("⚠️ 공유 링크 만료됨")
                    // 만료된 레코드 삭제 시도
                    try? await deleteShareRecord(shareID: shareID)
                    throw P2PShareError.shareExpired
                }
            }

            // 암호화된 데이터 추출
            guard let encryptedData = record[Fields.encryptedData] as? Data else {
                logger.error("❌ 암호화된 데이터 없음")
                throw P2PShareError.shareNotFound
            }

            // 사진 다운로드
            var photoURLs: [URL] = []
            if let assets = record[Fields.photos] as? [CKAsset] {
                for asset in assets {
                    if let fileURL = asset.fileURL {
                        photoURLs.append(fileURL)
                    }
                }
            }

            let expiresAt = record[Fields.expiresAt] as? Date

            logger.info("✅ 공유 패키지 다운로드 완료 (사진: \(photoURLs.count)개)")
            return (encryptedData, photoURLs, expiresAt)

        } catch let error as P2PShareError {
            throw error
        } catch let error as CKError {
            if error.code == .unknownItem {
                logger.error("❌ 공유 데이터를 찾을 수 없음")
                throw P2PShareError.shareNotFound
            }
            logger.error("❌ CloudKit 다운로드 실패: \(error.localizedDescription)")
            throw P2PShareError.cloudKitError(error)
        } catch {
            logger.error("❌ 다운로드 실패: \(error.localizedDescription)")
            throw P2PShareError.cloudKitError(error)
        }
    }

    // MARK: - Delete

    /// 공유 레코드 삭제
    /// - Parameter shareID: 공유 ID
    func deleteShareRecord(shareID: String) async throws {
        logger.info("☁️ 공유 레코드 삭제 (shareID: \(shareID))")

        let recordID = CKRecord.ID(recordName: shareID)

        do {
            try await publicDatabase.deleteRecord(withID: recordID)
            logger.info("✅ 공유 레코드 삭제 완료")
        } catch let error as CKError {
            if error.code == .unknownItem {
                logger.debug("ℹ️ 삭제할 레코드 없음 (이미 삭제됨)")
                return
            }
            logger.error("❌ CloudKit 삭제 실패: \(error.localizedDescription)")
            throw P2PShareError.cloudKitError(error)
        } catch {
            logger.error("❌ 삭제 실패: \(error.localizedDescription)")
            throw P2PShareError.cloudKitError(error)
        }
    }

    // MARK: - Check Existence

    /// 공유 레코드 존재 여부 확인
    /// - Parameter shareID: 공유 ID
    /// - Returns: 존재 여부
    func checkRecordExists(shareID: String) async -> Bool {
        logger.debug("☁️ 레코드 존재 확인 (shareID: \(shareID))")

        let recordID = CKRecord.ID(recordName: shareID)

        do {
            _ = try await publicDatabase.record(for: recordID)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Cleanup Expired Records

    /// 만료된 레코드 정리 (앱 시작 시 호출)
    func cleanupExpiredRecords() async {
        logger.info("☁️ 만료된 레코드 정리 시작")

        let predicate = NSPredicate(format: "%K < %@", Fields.expiresAt, Date() as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDatabase.records(matching: query)

            var deletedCount = 0
            for (recordID, result) in matchResults {
                if case .success = result {
                    try? await publicDatabase.deleteRecord(withID: recordID)
                    deletedCount += 1
                }
            }

            if deletedCount > 0 {
                logger.info("✅ 만료된 레코드 \(deletedCount)개 삭제 완료")
            } else {
                logger.debug("ℹ️ 만료된 레코드 없음")
            }

        } catch {
            logger.error("❌ 만료 레코드 정리 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Network Check

    /// 네트워크 가용성 확인
    private func checkNetworkAvailability() async throws {
        let status = try await container.accountStatus()

        switch status {
        case .available:
            logger.debug("☁️ iCloud 계정 사용 가능")
        case .noAccount:
            logger.warning("⚠️ iCloud 계정 없음 (익명 사용)")
            // Public Database는 계정 없이도 사용 가능
        case .restricted:
            logger.error("❌ iCloud 계정 제한됨")
            throw P2PShareError.networkUnavailable
        case .couldNotDetermine:
            logger.warning("⚠️ iCloud 계정 상태 확인 불가")
        case .temporarilyUnavailable:
            logger.error("❌ iCloud 일시적으로 사용 불가")
            throw P2PShareError.networkUnavailable
        @unknown default:
            logger.warning("⚠️ 알 수 없는 iCloud 상태")
        }
    }

    // MARK: - Fetch Share Info (Preview)

    /// 공유 미리보기 정보 조회 (암호화 데이터 없이)
    /// - Parameter shareID: 공유 ID
    /// - Returns: 사진 수, 만료 시간
    func fetchShareInfo(shareID: String) async throws -> (photoCount: Int, expiresAt: Date?) {
        logger.info("☁️ 공유 정보 조회 (shareID: \(shareID))")

        let recordID = CKRecord.ID(recordName: shareID)

        do {
            let record = try await publicDatabase.record(for: recordID)

            // 만료 확인
            if let expiresAt = record[Fields.expiresAt] as? Date, expiresAt < Date() {
                throw P2PShareError.shareExpired
            }

            let photoCount = record[Fields.photoCount] as? Int ?? 0
            let expiresAt = record[Fields.expiresAt] as? Date

            return (photoCount, expiresAt)

        } catch let error as P2PShareError {
            throw error
        } catch let error as CKError {
            if error.code == .unknownItem {
                throw P2PShareError.shareNotFound
            }
            throw P2PShareError.cloudKitError(error)
        } catch {
            throw P2PShareError.cloudKitError(error)
        }
    }
}
