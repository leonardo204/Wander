import Foundation
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AuthenticationManager")

/// 앱 인증 관리자 (PIN, 생체인증)
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()

    // MARK: - Properties
    private let keychainManager = KeychainManager.shared
    private let pinKey = "wander_user_pin"
    private let biometricEnabledKey = "wander_biometric_enabled"

    /// 인증 상태
    var isAuthenticated = false

    /// 마지막 인증 시간
    private var lastAuthTime: Date?

    /// 인증 유효 시간 (5분)
    private let authValidDuration: TimeInterval = 300

    /// 실패 횟수
    private(set) var failedAttempts = 0

    /// 잠금 해제 시간
    private(set) var lockoutEndTime: Date?

    /// 잠금 시간 (30초)
    private let lockoutDuration: TimeInterval = 30

    /// 최대 실패 횟수
    private let maxFailedAttempts = 3

    // MARK: - Computed Properties

    /// PIN이 설정되어 있는지
    var isPINSet: Bool {
        keychainManager.retrieve(key: pinKey) != nil
    }

    /// 생체인증 활성화 여부
    var isBiometricEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: biometricEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: biometricEnabledKey) }
    }

    /// 생체인증 사용 가능 여부
    var canUseBiometric: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// 생체인증 타입 (Face ID / Touch ID)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    /// 생체인증 아이콘
    var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }

    /// 생체인증 이름
    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "생체인증"
        }
    }

    /// 잠금 상태
    var isLockedOut: Bool {
        guard let endTime = lockoutEndTime else { return false }
        return Date() < endTime
    }

    /// 남은 잠금 시간 (초)
    var remainingLockoutSeconds: Int {
        guard let endTime = self.lockoutEndTime else { return 0 }
        let remaining = endTime.timeIntervalSinceNow
        return max(0, Int(remaining))
    }

    /// 인증이 아직 유효한지
    var isAuthenticationValid: Bool {
        guard isAuthenticated, let lastAuth = lastAuthTime else { return false }
        return Date().timeIntervalSince(lastAuth) < authValidDuration
    }

    // MARK: - Init
    private init() {}

    // MARK: - PIN Management

    /// PIN 설정
    func setPIN(_ pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy({ $0.isNumber }) else {
            logger.error("❌ [Auth] 잘못된 PIN 형식")
            return false
        }

        let success = keychainManager.save(key: pinKey, value: pin)
        if success {
            logger.info("🔐 [Auth] PIN 설정 완료")
        }
        return success
    }

    /// PIN 검증
    func verifyPIN(_ pin: String) -> Bool {
        // 잠금 상태 확인
        if isLockedOut {
            let remaining = self.remainingLockoutSeconds
            logger.warning("🔒 [Auth] 잠금 상태 - \(remaining)초 남음")
            return false
        }

        guard let storedPIN = keychainManager.retrieve(key: pinKey) else {
            logger.error("❌ [Auth] 저장된 PIN 없음")
            return false
        }

        if pin == storedPIN {
            // 성공
            failedAttempts = 0
            lockoutEndTime = nil
            markAuthenticated()
            logger.info("✅ [Auth] PIN 인증 성공")
            return true
        } else {
            // 실패
            failedAttempts += 1
            let attempts = self.failedAttempts
            let maxAttempts = self.maxFailedAttempts
            logger.warning("❌ [Auth] PIN 인증 실패 (\(attempts)/\(maxAttempts))")

            if failedAttempts >= maxFailedAttempts {
                lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
                let duration = Int(self.lockoutDuration)
                logger.warning("🔒 [Auth] \(maxAttempts)회 실패 - \(duration)초 잠금")
            }
            return false
        }
    }

    /// PIN 삭제
    func removePIN() {
        keychainManager.delete(key: pinKey)
        isBiometricEnabled = false
        invalidateAuthentication()
        logger.info("🗑️ [Auth] PIN 삭제됨")
    }

    // MARK: - Biometric Authentication

    /// 생체인증 수행
    func authenticateWithBiometric() async -> Bool {
        guard canUseBiometric && isBiometricEnabled else {
            logger.info("ℹ️ [Auth] 생체인증 사용 불가 또는 비활성화")
            return false
        }

        let context = LAContext()
        let reason = "숨긴 기록을 보려면 인증이 필요합니다"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                await MainActor.run {
                    markAuthenticated()
                }
                logger.info("✅ [Auth] 생체인증 성공")
            }
            return success
        } catch {
            logger.warning("❌ [Auth] 생체인증 실패: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Authentication State

    /// 인증 완료 처리
    func markAuthenticated() {
        isAuthenticated = true
        lastAuthTime = Date()
        failedAttempts = 0
        lockoutEndTime = nil
    }

    /// 인증 무효화
    func invalidateAuthentication() {
        isAuthenticated = false
        lastAuthTime = nil
    }

    /// 인증 유효성 확인 및 필요시 재인증 요청
    func checkAndRefreshAuthentication() -> Bool {
        if isAuthenticationValid {
            return true
        }
        invalidateAuthentication()
        return false
    }

    /// 잠금 해제 (테스트/디버그용)
    func resetLockout() {
        failedAttempts = 0
        lockoutEndTime = nil
    }
}
