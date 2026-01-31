import Foundation
import Security

/// Keychain을 사용하여 API 키를 안전하게 저장하는 매니저
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.zerolive.wander"

    private init() {}

    // MARK: - API Key Storage

    enum APIKeyType: String {
        case openai = "openai_api_key"
        case anthropic = "anthropic_api_key"
        case google = "google_api_key"
    }

    /// API 키 저장
    func saveAPIKey(_ key: String, for type: APIKeyType) throws {
        let data = key.data(using: .utf8)!

        // 기존 키 삭제
        try? deleteAPIKey(for: type)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// API 키 조회
    func getAPIKey(for type: APIKeyType) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                return nil
            }
            return key

        case errSecItemNotFound:
            return nil

        default:
            throw KeychainError.readFailed(status)
        }
    }

    /// API 키 삭제
    func deleteAPIKey(for type: APIKeyType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// API 키 존재 여부 확인
    func hasAPIKey(for type: APIKeyType) -> Bool {
        do {
            return try getAPIKey(for: type) != nil
        } catch {
            return false
        }
    }

    /// 모든 API 키 삭제
    func deleteAllAPIKeys() {
        for type in [APIKeyType.openai, .anthropic, .google] {
            try? deleteAPIKey(for: type)
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "키 저장 실패 (코드: \(status))"
        case .readFailed(let status):
            return "키 조회 실패 (코드: \(status))"
        case .deleteFailed(let status):
            return "키 삭제 실패 (코드: \(status))"
        }
    }
}
