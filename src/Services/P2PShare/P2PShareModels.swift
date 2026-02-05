import Foundation

// MARK: - Share Package (공유 패키지)

/// 공유할 여행 기록 전체 패키지
struct SharePackage: Codable {
    let version: Int
    let shareID: UUID
    let createdAt: Date
    let expiresAt: Date?
    let senderName: String?

    let record: SharedTravelRecord
    let photoReferences: [PhotoReference]

    init(
        shareID: UUID = UUID(),
        createdAt: Date = Date(),
        expiresAt: Date?,
        senderName: String?,
        record: SharedTravelRecord,
        photoReferences: [PhotoReference]
    ) {
        self.version = 1
        self.shareID = shareID
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.senderName = senderName
        self.record = record
        self.photoReferences = photoReferences
    }
}

// MARK: - Shared Travel Record

/// 공유용 여행 기록 (TravelRecord의 Codable 버전)
struct SharedTravelRecord: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let totalDistance: Double
    let aiStory: String?
    let days: [SharedTravelDay]
}

/// 공유용 여행 일자
struct SharedTravelDay: Codable {
    let date: Date
    let dayNumber: Int
    let places: [SharedPlace]
}

/// 공유용 장소
struct SharedPlace: Codable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date?
    let activityLabel: String
    let photoIndices: [Int]  // photoReferences 배열의 인덱스
}

/// 사진 참조 정보
struct PhotoReference: Codable {
    let index: Int
    let filename: String
    let capturedAt: Date?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Share Options (공유 옵션)

/// 사진 품질 옵션
enum PhotoQuality: String, CaseIterable, Identifiable {
    case original = "original"
    case optimized = "optimized"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: return "원본"
        case .optimized: return "최적화"
        }
    }

    var description: String {
        switch self {
        case .original: return "원본 해상도 그대로"
        case .optimized: return "2048px 기준 리사이즈 (용량 절감)"
        }
    }

    /// 최적화 시 최대 픽셀 크기
    var maxPixelSize: Int? {
        switch self {
        case .original: return nil
        case .optimized: return 2048
        }
    }
}

/// 링크 만료 옵션
enum LinkExpiration: String, CaseIterable, Identifiable {
    case threeMinutes = "3min"
    case oneDay = "1day"
    case sevenDays = "7days"
    case thirtyDays = "30days"
    case never = "never"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeMinutes: return "3분"
        case .oneDay: return "1일"
        case .sevenDays: return "7일"
        case .thirtyDays: return "30일"
        case .never: return "영구"
        }
    }

    /// 만료 날짜 계산
    var expirationDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .threeMinutes:
            return calendar.date(byAdding: .minute, value: 3, to: Date())
        case .oneDay:
            return calendar.date(byAdding: .day, value: 1, to: Date())
        case .sevenDays:
            return calendar.date(byAdding: .day, value: 7, to: Date())
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: 30, to: Date())
        case .never:
            return nil
        }
    }
}

/// 공유 설정
struct ShareOptions {
    var photoQuality: PhotoQuality = .optimized
    var linkExpiration: LinkExpiration = .sevenDays
    var senderName: String?
}

// MARK: - Share Result

/// 공유 링크 생성 결과
struct P2PShareResult {
    let shareID: UUID
    let shareURL: URL
    let expiresAt: Date?
    let photoCount: Int
    let totalSize: Int64  // bytes
}

/// P2PShareResult를 sheet(item:)에서 사용하기 위한 래퍼
struct P2PShareResultWrapper: Identifiable {
    let id = UUID()
    let result: P2PShareResult
}

/// 공유 수신 미리보기 정보
struct SharePreview {
    let shareID: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let placeCount: Int
    let totalDistance: Double
    let photoCount: Int
    let senderName: String?
    let expiresAt: Date?
    let thumbnailData: Data?
}

// MARK: - Errors

/// P2P 공유 에러
enum P2PShareError: LocalizedError {
    case networkUnavailable
    case cloudKitError(Error)
    case encryptionFailed
    case decryptionFailed
    case invalidShareLink
    case shareExpired
    case shareNotFound
    case duplicateShare
    case storageFull
    case photoLoadFailed
    case serializationFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "네트워크 연결을 확인하세요"
        case .cloudKitError(let error):
            return "클라우드 오류: \(error.localizedDescription)"
        case .encryptionFailed:
            return "데이터 암호화에 실패했습니다"
        case .decryptionFailed:
            return "링크가 손상되었습니다"
        case .invalidShareLink:
            return "유효하지 않은 공유 링크입니다"
        case .shareExpired:
            return "이 공유 링크는 만료되었습니다"
        case .shareNotFound:
            return "공유 데이터를 찾을 수 없습니다"
        case .duplicateShare:
            return "이미 저장된 기록입니다"
        case .storageFull:
            return "저장 공간이 부족합니다"
        case .photoLoadFailed:
            return "사진을 불러오는데 실패했습니다"
        case .serializationFailed:
            return "데이터 변환에 실패했습니다"
        case .unknown(let error):
            return "오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - Deep Link

/// 공유 딥링크 파싱 결과
///
/// 현재: Custom URL Scheme (wander://...) 사용
/// TODO: Universal Link 활성화 시 도메인 필요
///       - wander.zerolive.com 도메인에 AASA 파일 호스팅
///       - Wander.entitlements에서 Associated Domains 주석 해제
struct ShareDeepLink {
    let shareID: String
    let encryptionKey: String

    /// Universal Link URL 생성
    /// TODO: 도메인 활성화 후 사용 가능
    var universalLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wander.zerolive.com"
        components.path = "/share/\(shareID)"
        components.queryItems = [
            URLQueryItem(name: "key", value: encryptionKey)
        ]
        return components.url
    }

    /// Custom URL Scheme 생성
    var customSchemeURL: URL? {
        var components = URLComponents()
        components.scheme = "wander"
        components.host = "share"
        components.path = "/\(shareID)"
        components.queryItems = [
            URLQueryItem(name: "key", value: encryptionKey)
        ]
        return components.url
    }

    /// URL에서 딥링크 파싱
    static func parse(from url: URL) -> ShareDeepLink? {
        // Universal Link: https://wander.zerolive.com/share/{shareID}?key={key}
        // Custom Scheme: wander://share/{shareID}?key={key}

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // shareID 추출
        var shareID: String?
        if url.scheme == "https" && url.host == "wander.zerolive.com" {
            // Universal Link: /share/{shareID}
            if pathComponents.count >= 2 && pathComponents[0] == "share" {
                shareID = pathComponents[1]
            }
        } else if url.scheme == "wander" {
            // Custom Scheme: wander://share/{shareID}
            if url.host == "share" && pathComponents.count >= 1 {
                shareID = pathComponents[0]
            }
        }

        // encryptionKey 추출
        guard let shareID = shareID,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let keyItem = components.queryItems?.first(where: { $0.name == "key" }),
              let encryptionKey = keyItem.value else {
            return nil
        }

        return ShareDeepLink(shareID: shareID, encryptionKey: encryptionKey)
    }
}
