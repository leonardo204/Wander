import Foundation
import UIKit
import Network
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "GoogleOAuth")

/// Google OAuth 2.0 서비스 (Gemini API용)
/// - NOTE: Gemini CLI의 OAuth 자격증명을 재사용하는 비공식 방식
/// - Gemini CLI Client ID는 Desktop 타입 → localhost 리다이렉트만 지원
/// - 로컬 HTTP 서버로 OAuth 콜백을 수신하여 auth code 획득
final class GoogleOAuthService: NSObject, ObservableObject {
    static let shared = GoogleOAuthService()

    // MARK: - OAuth Configuration (Secrets.plist에서 로드)

    /// Gemini CLI가 사용하는 OAuth Client ID (Desktop 타입)
    /// - NOTE: Resources/Secrets.plist에서 로드 (Git 추적 제외)
    /// - Related: https://github.com/ericc-ch/opencode-google-auth
    private static let embeddedClientID: String = {
        loadSecret(key: "GOOGLE_OAUTH_CLIENT_ID") ?? ""
    }()
    private static let clientSecret: String = {
        loadSecret(key: "GOOGLE_OAUTH_CLIENT_SECRET") ?? ""
    }()

    /// Secrets.plist에서 값 로드
    private static func loadSecret(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            logger.error("🔐 [OAuth] Secrets.plist 로드 실패 - \(key)")
            return nil
        }
        return plist[key]
    }

    private let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"

    /// Gemini CLI가 사용하는 OAuth scopes
    /// - cloud-platform: Cloud Code Assist API 접근 (cloudcode-pa.googleapis.com)
    /// - userinfo.email/profile: 사용자 정보 확인
    private let scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ]

    // MARK: - Keychain Keys

    private let accessTokenKey = "google_oauth_access_token"
    private let refreshTokenKey = "google_oauth_refresh_token"
    private let tokenExpiryKey = "google_oauth_token_expiry"
    private let projectIDKey = "google_oauth_project_id"

    /// Cloud Code Assist API 엔드포인트
    static let cloudCodeBaseURL = "https://cloudcode-pa.googleapis.com/v1internal"

    // MARK: - State

    @Published var isAuthenticated: Bool = false

    /// 로컬 OAuth 콜백 서버
    private var callbackServer: NWListener?
    /// auth code 수신 대기용
    private var authCodeContinuation: CheckedContinuation<String, Error>?

    private override init() {
        super.init()
        isAuthenticated = hasValidTokens()
    }

    // MARK: - Public Interface

    var clientID: String {
        Self.embeddedClientID
    }

    /// OAuth 인증 여부 확인 (토큰 존재 확인)
    func hasValidTokens() -> Bool {
        if KeychainManager.shared.retrieve(key: accessTokenKey) != nil,
           let expiryString = KeychainManager.shared.retrieve(key: tokenExpiryKey),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry {
            return true
        }
        return KeychainManager.shared.retrieve(key: refreshTokenKey) != nil
    }

    /// 현재 유효한 Access Token 반환 (필요시 자동 갱신)
    func getValidAccessToken() async throws -> String {
        if let token = KeychainManager.shared.retrieve(key: accessTokenKey),
           let expiryString = KeychainManager.shared.retrieve(key: tokenExpiryKey),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry {
            return token
        }

        if let refreshToken = KeychainManager.shared.retrieve(key: refreshTokenKey) {
            return try await refreshAccessToken(refreshToken: refreshToken)
        }

        throw GoogleOAuthError.notAuthenticated
    }

    // MARK: - Authentication Flow

    /// OAuth 인증 시작
    /// 1. 로컬 HTTP 서버 시작 → 2. Safari로 Google 인증 → 3. localhost 콜백 수신 → 4. 토큰 교환
    @MainActor
    func authenticate() async throws {
        let clientID = self.clientID

        // 1. 로컬 콜백 서버 시작
        let port = try await startCallbackServer()
        let redirectURI = "http://127.0.0.1:\(port)/callback"

        logger.info("🔐 [OAuth] 인증 시작 - 로컬 서버 포트: \(port)")

        // 2. 인증 URL 구성
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        guard let authURL = components.url else {
            stopCallbackServer()
            throw GoogleOAuthError.invalidClientID
        }

        // 3. Safari에서 인증 페이지 열기
        await UIApplication.shared.open(authURL)

        // 4. 로컬 서버에서 auth code 수신 대기 (최대 5분)
        let code: String
        do {
            code = try await waitForAuthCode(timeout: 300)
        } catch {
            stopCallbackServer()
            throw error
        }

        stopCallbackServer()

        logger.info("🔐 [OAuth] 인증 코드 수신 성공")

        // 5. Authorization Code → Access/Refresh Token 교환
        try await exchangeCodeForTokens(
            code: code,
            clientID: clientID,
            redirectURI: redirectURI
        )

        isAuthenticated = true
        logger.info("🔐 [OAuth] 인증 완료")
    }

    /// 연결 테스트 (loadCodeAssist로 Cloud Code API 접근 확인)
    func testConnection() async throws -> Bool {
        let _ = try await getProjectID()
        logger.info("🔐 [OAuth] 연결 테스트 성공 (Cloud Code Assist)")
        return true
    }

    // MARK: - Cloud Code Assist API

    /// 프로젝트 ID 반환 (캐시 → loadCodeAssist)
    func getProjectID() async throws -> String {
        if let projectID = KeychainManager.shared.retrieve(key: projectIDKey) {
            return projectID
        }
        return try await loadCodeAssist()
    }

    /// Cloud Code Assist API로 프로젝트 ID 획득
    /// - Gemini CLI 인증 후 사용자의 Cloud 프로젝트가 자동 할당됨
    private func loadCodeAssist() async throws -> String {
        let token = try await getValidAccessToken()

        let url = URL(string: "\(Self.cloudCodeBaseURL):loadCodeAssist")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.authenticationFailed("잘못된 응답")
        }

        let body = String(data: data, encoding: .utf8) ?? "no body"
        logger.info("🔐 [OAuth] loadCodeAssist - status: \(httpResponse.statusCode), body: \(body)")

        guard httpResponse.statusCode == 200 else {
            // 온보딩 필요 시 시도
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 404 {
                logger.info("🔐 [OAuth] 온보딩 시도...")
                try await onboardUser()
                return try await retryLoadCodeAssist()
            }
            throw GoogleOAuthError.authenticationFailed("프로젝트 설정 실패 (HTTP \(httpResponse.statusCode))")
        }

        return try parseProjectID(from: data)
    }

    /// 사용자 온보딩 (첫 사용 시 필요)
    private func onboardUser() async throws {
        let token = try await getValidAccessToken()

        let url = URL(string: "\(Self.cloudCodeBaseURL):onboardUser")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let body = String(data: data, encoding: .utf8) ?? "no body"

        if let httpResponse = response as? HTTPURLResponse {
            logger.info("🔐 [OAuth] onboardUser - status: \(httpResponse.statusCode), body: \(body)")
        }
    }

    /// loadCodeAssist 재시도 (온보딩 후)
    private func retryLoadCodeAssist() async throws -> String {
        let token = try await getValidAccessToken()

        let url = URL(string: "\(Self.cloudCodeBaseURL):loadCodeAssist")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("🔐 [OAuth] loadCodeAssist 재시도 실패: \(body)")
            throw GoogleOAuthError.authenticationFailed("프로젝트 설정 실패")
        }

        return try parseProjectID(from: data)
    }

    /// loadCodeAssist 응답에서 프로젝트 ID 추출
    private func parseProjectID(from data: Data) throws -> String {
        // JSON 응답에서 project 필드 탐색
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleOAuthError.authenticationFailed("프로젝트 ID 파싱 실패")
        }

        // 프로젝트 ID 필드 탐색 (우선순위 순)
        for key in ["cloudaicompanionProject", "project", "billingProject", "projectId"] {
            if let value = json[key] as? String, !value.isEmpty {
                _ = KeychainManager.shared.save(key: projectIDKey, value: value)
                logger.info("🔐 [OAuth] 프로젝트 ID (\(key)): \(value)")
                return value
            }
        }

        // name 필드에서 추출 시도 (예: "projects/gen-lang-client-XXX")
        if let name = json["name"] as? String, name.contains("projects/") {
            let projectID = name.replacingOccurrences(of: "projects/", with: "")
            _ = KeychainManager.shared.save(key: projectIDKey, value: projectID)
            logger.info("🔐 [OAuth] 프로젝트 ID (name에서): \(projectID)")
            return projectID
        }

        logger.error("🔐 [OAuth] 프로젝트 ID를 찾을 수 없음 - keys: \(json.keys.joined(separator: ", "))")
        throw GoogleOAuthError.authenticationFailed("프로젝트 ID를 찾을 수 없습니다")
    }

    /// 로그아웃 (토큰 + 프로젝트 ID 삭제)
    func logout() {
        logger.info("🔐 [OAuth] 로그아웃")
        KeychainManager.shared.delete(key: accessTokenKey)
        KeychainManager.shared.delete(key: refreshTokenKey)
        KeychainManager.shared.delete(key: tokenExpiryKey)
        KeychainManager.shared.delete(key: projectIDKey)
        isAuthenticated = false
    }

    /// 모든 OAuth 데이터 삭제
    func deleteAll() {
        logger.info("🔐 [OAuth] 모든 OAuth 데이터 삭제")
        logout()
    }

    // MARK: - Local Callback Server

    /// 로컬 HTTP 서버 시작 (OAuth 콜백 수신용)
    /// - Returns: 할당된 포트 번호
    private func startCallbackServer() async throws -> UInt16 {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            var hasResumed = false

            do {
                let listener = try NWListener(using: .tcp, on: .any)

                listener.stateUpdateHandler = { state in
                    guard !hasResumed else { return }
                    switch state {
                    case .ready:
                        if let port = listener.port?.rawValue {
                            hasResumed = true
                            continuation.resume(returning: port)
                        }
                    case .failed(let error):
                        hasResumed = true
                        continuation.resume(throwing: GoogleOAuthError.authenticationFailed("서버 시작 실패: \(error.localizedDescription)"))
                    case .cancelled:
                        hasResumed = true
                        continuation.resume(throwing: GoogleOAuthError.sessionStartFailed)
                    default:
                        break
                    }
                }

                listener.newConnectionHandler = { [weak self] connection in
                    self?.handleOAuthCallback(connection: connection)
                }

                self?.callbackServer = listener
                listener.start(queue: .global(qos: .userInitiated))
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// auth code 수신 대기 (타임아웃 포함)
    private func waitForAuthCode(timeout: TimeInterval) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { [weak self] group in
            // auth code 수신 대기
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    Task { @MainActor [weak self] in
                        self?.authCodeContinuation = continuation
                    }
                }
            }

            // 타임아웃
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw GoogleOAuthError.authenticationFailed("인증 시간이 초과되었습니다 (5분)")
            }

            guard let result = try await group.next() else {
                throw GoogleOAuthError.noAuthorizationCode
            }
            group.cancelAll()
            return result
        }
    }

    /// OAuth 콜백 HTTP 요청 처리
    /// - Google이 redirect하는 `http://127.0.0.1:{port}/callback?code=...` 수신
    private func handleOAuthCallback(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let data = data,
                  let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            // HTTP 요청 라인 파싱: "GET /callback?code=...&scope=... HTTP/1.1"
            let lines = requestString.components(separatedBy: "\r\n")
            guard let requestLine = lines.first else {
                connection.cancel()
                return
            }

            let parts = requestLine.components(separatedBy: " ")
            guard parts.count >= 2 else {
                connection.cancel()
                return
            }

            let path = parts[1]
            guard let url = URL(string: "http://localhost\(path)"),
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                connection.cancel()
                return
            }

            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                // 인증 성공 → HTML 응답
                let html = """
                <!DOCTYPE html>
                <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Wander - 인증 완료</title>
                <style>
                body { font-family: -apple-system, system-ui; display: flex; justify-content: center;
                       align-items: center; min-height: 100vh; margin: 0; background: #f0f8ff; }
                .card { text-align: center; padding: 40px; background: white; border-radius: 16px;
                        box-shadow: 0 4px 24px rgba(0,0,0,0.1); max-width: 320px; }
                h1 { color: #1a2b33; font-size: 24px; }
                p { color: #5a6b73; font-size: 16px; line-height: 1.5; }
                .icon { font-size: 48px; margin-bottom: 16px; }
                </style></head>
                <body><div class="card">
                <div class="icon">✅</div>
                <h1>인증 완료</h1>
                <p>Google 계정이 연결되었습니다.<br>Wander 앱으로 돌아가세요.</p>
                </div></body></html>
                """
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"

                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                logger.info("🔐 [OAuth] 로컬 서버 - 인증 코드 수신 완료")
                self?.authCodeContinuation?.resume(returning: code)
                self?.authCodeContinuation = nil

            } else if let errorParam = components.queryItems?.first(where: { $0.name == "error" })?.value {
                // 인증 실패
                let html = "<html><body><h1>인증 실패</h1><p>\(errorParam)</p></body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"

                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })

                self?.authCodeContinuation?.resume(throwing: GoogleOAuthError.authenticationFailed(errorParam))
                self?.authCodeContinuation = nil
            } else {
                connection.cancel()
            }
        }
    }

    /// 로컬 콜백 서버 중지
    private func stopCallbackServer() {
        callbackServer?.cancel()
        callbackServer = nil
    }

    // MARK: - Token Exchange

    /// Authorization Code를 Access/Refresh Token으로 교환
    private func exchangeCodeForTokens(
        code: String,
        clientID: String,
        redirectURI: String
    ) async throws {
        logger.info("🔐 [OAuth] 토큰 교환 시작")

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "client_secret": Self.clientSecret,
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleOAuthError.tokenExchangeFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                logger.error("🔐 [OAuth] 토큰 교환 실패: \(errorResponse.error) - \(errorResponse.errorDescription ?? "")")
                throw GoogleOAuthError.tokenExchangeFailed(errorResponse.errorDescription ?? errorResponse.error)
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("🔐 [OAuth] 토큰 교환 실패 - status: \(httpResponse.statusCode), body: \(errorBody)")
            throw GoogleOAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        saveTokens(tokenResponse)

        logger.info("🔐 [OAuth] 토큰 저장 완료 - expires_in: \(tokenResponse.expiresIn ?? 0)초")
    }

    /// Refresh Token으로 Access Token 갱신
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        logger.info("🔐 [OAuth] 토큰 갱신 시작")

        let clientID = self.clientID

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": Self.clientSecret,
        ]

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logger.error("🔐 [OAuth] 토큰 갱신 실패 - 재인증 필요")
            await MainActor.run { logout() }
            throw GoogleOAuthError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        saveTokens(tokenResponse)

        guard let accessToken = tokenResponse.accessToken else {
            throw GoogleOAuthError.tokenRefreshFailed
        }

        logger.info("🔐 [OAuth] 토큰 갱신 성공")
        return accessToken
    }

    // MARK: - Token Storage

    private func saveTokens(_ response: OAuthTokenResponse) {
        if let accessToken = response.accessToken {
            _ = KeychainManager.shared.save(key: accessTokenKey, value: accessToken)
        }
        if let refreshToken = response.refreshToken {
            _ = KeychainManager.shared.save(key: refreshTokenKey, value: refreshToken)
        }
        if let expiresIn = response.expiresIn {
            // 5분 여유를 두고 만료 시간 저장
            let expiry = Date().timeIntervalSince1970 + Double(expiresIn) - 300
            _ = KeychainManager.shared.save(key: tokenExpiryKey, value: String(expiry))
        }
    }
}

// MARK: - OAuth Response Models

private struct OAuthTokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

private struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - OAuth Errors

enum GoogleOAuthError: LocalizedError {
    case noClientID
    case invalidClientID
    case notAuthenticated
    case userCancelled
    case noCallbackURL
    case noAuthorizationCode
    case authenticationFailed(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case sessionStartFailed

    var errorDescription: String? {
        switch self {
        case .noClientID:
            return "Google OAuth Client ID가 설정되지 않았습니다."
        case .invalidClientID:
            return "유효하지 않은 Client ID입니다."
        case .notAuthenticated:
            return "Google 계정 인증이 필요합니다."
        case .userCancelled:
            return "인증이 취소되었습니다."
        case .noCallbackURL:
            return "인증 응답을 받지 못했습니다."
        case .noAuthorizationCode:
            return "인증 코드를 받지 못했습니다."
        case .authenticationFailed(let detail):
            return "인증 실패: \(detail)"
        case .tokenExchangeFailed(let detail):
            return "토큰 교환 실패: \(detail)"
        case .tokenRefreshFailed:
            return "토큰 갱신에 실패했습니다. 다시 인증해 주세요."
        case .sessionStartFailed:
            return "인증 세션을 시작할 수 없습니다."
        }
    }
}
