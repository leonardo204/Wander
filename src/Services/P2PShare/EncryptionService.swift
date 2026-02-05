import Foundation
import CryptoKit
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "EncryptionService")

// MARK: - Encryption Service

/// AES-256-GCM 암호화 서비스
final class EncryptionService {

    static let shared = EncryptionService()

    private init() {}

    // MARK: - Key Generation

    /// 256-bit 암호화 키 생성
    func generateEncryptionKey() -> SymmetricKey {
        logger.debug("🔐 암호화 키 생성")
        return SymmetricKey(size: .bits256)
    }

    // MARK: - Encryption

    /// 데이터 암호화 (AES-256-GCM)
    /// - Parameters:
    ///   - data: 암호화할 데이터
    ///   - key: 암호화 키
    /// - Returns: 암호화된 데이터 (nonce + ciphertext + tag)
    func encrypt(data: Data, key: SymmetricKey) throws -> Data {
        logger.debug("🔐 데이터 암호화 시작 (크기: \(data.count) bytes)")

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            // combined = nonce (12 bytes) + ciphertext + tag (16 bytes)
            guard let combinedData = sealedBox.combined else {
                logger.error("❌ 암호화 데이터 결합 실패")
                throw P2PShareError.encryptionFailed
            }

            logger.debug("✅ 암호화 완료 (암호화된 크기: \(combinedData.count) bytes)")
            return combinedData

        } catch let error as P2PShareError {
            throw error
        } catch {
            logger.error("❌ 암호화 실패: \(error.localizedDescription)")
            throw P2PShareError.encryptionFailed
        }
    }

    // MARK: - Decryption

    /// 데이터 복호화 (AES-256-GCM)
    /// - Parameters:
    ///   - encryptedData: 암호화된 데이터 (nonce + ciphertext + tag)
    ///   - key: 복호화 키
    /// - Returns: 원본 데이터
    func decrypt(encryptedData: Data, key: SymmetricKey) throws -> Data {
        logger.debug("🔓 데이터 복호화 시작 (크기: \(encryptedData.count) bytes)")

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            logger.debug("✅ 복호화 완료 (원본 크기: \(decryptedData.count) bytes)")
            return decryptedData

        } catch {
            logger.error("❌ 복호화 실패: \(error.localizedDescription)")
            throw P2PShareError.decryptionFailed
        }
    }

    // MARK: - Key Encoding/Decoding

    /// 암호화 키를 URL-safe Base64로 인코딩
    /// - Parameter key: 암호화 키
    /// - Returns: Base64URL 인코딩된 문자열
    func encodeKeyForURL(_ key: SymmetricKey) -> String {
        let keyData = key.withUnsafeBytes { Data($0) }
        return base64URLEncode(keyData)
    }

    /// URL-safe Base64 문자열을 암호화 키로 디코딩
    /// - Parameter encodedKey: Base64URL 인코딩된 문자열
    /// - Returns: 암호화 키
    func decodeKeyFromURL(_ encodedKey: String) throws -> SymmetricKey {
        guard let keyData = base64URLDecode(encodedKey) else {
            logger.error("❌ 키 디코딩 실패: 유효하지 않은 Base64URL")
            throw P2PShareError.invalidShareLink
        }

        // 256-bit = 32 bytes
        guard keyData.count == 32 else {
            logger.error("❌ 키 길이 오류: \(keyData.count) bytes (expected 32)")
            throw P2PShareError.invalidShareLink
        }

        return SymmetricKey(data: keyData)
    }

    // MARK: - Base64URL Encoding

    /// Base64URL 인코딩 (URL-safe, padding 제거)
    private func base64URLEncode(_ data: Data) -> String {
        var base64 = data.base64EncodedString()
        base64 = base64.replacingOccurrences(of: "+", with: "-")
        base64 = base64.replacingOccurrences(of: "/", with: "_")
        base64 = base64.replacingOccurrences(of: "=", with: "")
        return base64
    }

    /// Base64URL 디코딩
    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")

        // padding 추가
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }

    // MARK: - Convenience Methods

    /// Codable 객체를 암호화
    func encrypt<T: Encodable>(_ object: T, key: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonData: Data
        do {
            jsonData = try encoder.encode(object)
        } catch {
            logger.error("❌ JSON 인코딩 실패: \(error.localizedDescription)")
            throw P2PShareError.serializationFailed
        }

        return try encrypt(data: jsonData, key: key)
    }

    /// 암호화된 데이터를 Codable 객체로 복호화
    func decrypt<T: Decodable>(_ type: T.Type, from encryptedData: Data, key: SymmetricKey) throws -> T {
        let jsonData = try decrypt(encryptedData: encryptedData, key: key)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(type, from: jsonData)
        } catch {
            logger.error("❌ JSON 디코딩 실패: \(error.localizedDescription)")
            throw P2PShareError.serializationFailed
        }
    }
}
