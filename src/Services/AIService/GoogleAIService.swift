import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "GoogleAIService")

/// Google Gemini 모델 목록
enum GeminiModel: String, CaseIterable, Identifiable {
    case gemini25Flash = "gemini-2.5-flash"
    case gemini2Flash = "gemini-2.0-flash"
    case gemini2FlashLite = "gemini-2.0-flash-lite"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini2Flash: return "Gemini 2.0 Flash"
        case .gemini2FlashLite: return "Gemini 2.0 Flash Lite"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        }
    }

    var description: String {
        switch self {
        case .gemini25Flash: return "최신 모델, 추론 능력 강화"
        case .gemini2Flash: return "빠르고 정확한 모델"
        case .gemini2FlashLite: return "경량 모델, 더 빠른 응답"
        case .gemini15Pro: return "고성능 모델"
        case .gemini15Flash: return "균형잡힌 성능"
        }
    }

    /// 스토리 생성 시 권장 최대 출력 토큰
    var storyMaxTokens: Int {
        switch self {
        case .gemini25Flash: return 1024
        case .gemini2Flash: return 1024
        case .gemini2FlashLite: return 512
        case .gemini15Pro: return 1024
        case .gemini15Flash: return 800
        }
    }

    /// 스토리 생성 temperature (창의성 조절)
    var storyTemperature: Double {
        switch self {
        case .gemini25Flash: return 0.7
        case .gemini2Flash: return 0.7
        case .gemini2FlashLite: return 0.6
        case .gemini15Pro: return 0.8
        case .gemini15Flash: return 0.7
        }
    }
}

/// Google Gemini API 서비스
/// - NOTE: OAuth → Cloud Code Assist API (cloudcode-pa.googleapis.com)
/// - NOTE: API Key → 표준 Gemini API (generativelanguage.googleapis.com)
final class GoogleAIService: AIServiceProtocol {
    let provider: AIProvider = .google

    private var model: String {
        Self.getSelectedModel().rawValue
    }

    private var apiKey: String? {
        try? KeychainManager.shared.getAPIKey(for: .google)
    }

    /// OAuth 인증이 활성화되어 있는지 확인
    private var hasOAuth: Bool {
        GoogleOAuthService.shared.isAuthenticated
    }

    /// 표준 Gemini API 엔드포인트 (API Key 방식)
    private var standardBaseURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model)"
    }

    /// 인증 방식 확인 (OAuth 또는 API Key가 하나라도 있으면 true)
    var hasAnyAuth: Bool {
        hasOAuth || apiKey != nil
    }

    // MARK: - Model Selection

    private static let modelKey = "google_gemini_model"

    static func getSelectedModel() -> GeminiModel {
        if let rawValue = UserDefaults.standard.string(forKey: modelKey),
           let model = GeminiModel(rawValue: rawValue) {
            return model
        }
        return .gemini25Flash  // 기본값
    }

    static func setSelectedModel(_ model: GeminiModel) {
        UserDefaults.standard.set(model.rawValue, forKey: modelKey)
    }

    // MARK: - Request Builder

    /// 인증 방식에 따른 URLRequest 생성
    /// - OAuth: Cloud Code Assist API (cloudcode-pa.googleapis.com/v1internal)
    /// - API Key: 표준 Gemini API (generativelanguage.googleapis.com/v1beta)
    private func buildGeminiRequest(
        contents: [GeminiContent],
        generationConfig: GeminiGenerationConfig?,
        timeoutInterval: TimeInterval = 30
    ) async throws -> URLRequest {
        let geminiRequest = GeminiRequest(contents: contents, generationConfig: generationConfig)

        if hasOAuth {
            // Cloud Code Assist API (OAuth)
            do {
                let token = try await GoogleOAuthService.shared.getValidAccessToken()
                let projectID = try await GoogleOAuthService.shared.getProjectID()

                let url = URL(string: "\(GoogleOAuthService.cloudCodeBaseURL):generateContent")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = timeoutInterval

                let wrappedBody = CloudCodeRequest(
                    model: model,
                    project: projectID,
                    request: geminiRequest
                )
                request.httpBody = try JSONEncoder().encode(wrappedBody)

                logger.info("💎 [Google] Cloud Code API - project: \(projectID), model: \(self.model)")
                return request
            } catch {
                logger.warning("💎 [Google] OAuth 요청 생성 실패, API Key 시도: \(error.localizedDescription)")
                // API Key 폴백
            }
        }

        // 표준 Gemini API (API Key)
        guard let apiKey = apiKey else {
            throw AIServiceError.noAPIKey
        }

        let url = URL(string: "\(standardBaseURL):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONEncoder().encode(geminiRequest)

        return request
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        logger.info("💎 [Google] testConnection 시작 - model: \(self.model)")

        let request = try await buildGeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: "1")])],
            generationConfig: GeminiGenerationConfig(maxOutputTokens: 1)
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                logger.info("💎 [Google] 연결 테스트 성공")
                return true
            case 429:
                logger.info("💎 [Google] 429 - Rate limit (인증 유효, 요청 제한)")
                return true
            case 400:
                logger.error("💎 [Google] 400 - 잘못된 요청")
                throw AIServiceError.invalidAPIKey
            case 401, 403:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] \(httpResponse.statusCode) - body: \(errorBody)")
                throw AIServiceError.invalidAPIKey
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] 서버 오류: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error("💎 [Google] 네트워크 오류: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Story

    func generateStory(from travelData: TravelStoryInput) async throws -> String {
        let selectedModel = Self.getSelectedModel()
        logger.info("💎 [Google] generateStory 시작 - model: \(selectedModel.displayName), places: \(travelData.places.count)개")

        let prompt = buildPrompt(from: travelData)
        let fullPrompt = "\(systemPrompt)\n\n\(prompt)"

        let request = try await buildGeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: fullPrompt)])],
            generationConfig: GeminiGenerationConfig(
                temperature: selectedModel.storyTemperature,
                maxOutputTokens: selectedModel.storyMaxTokens
            )
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let result = try decodeGeminiResponse(from: data)
                guard let text = result.candidates?.first?.content.parts.first?.text else {
                    logger.error("💎 [Google] 응답 파싱 실패 - text 없음")
                    throw AIServiceError.invalidResponse
                }
                logger.info("💎 [Google] 스토리 생성 성공 - length: \(text.count)자")
                return text

            case 400, 401, 403:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] generateStory 실패 - status: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.invalidAPIKey
            case 429:
                throw AIServiceError.rateLimitExceeded
            default:
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch is DecodingError {
            throw AIServiceError.decodingError
        } catch {
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Content (범용)

    func generateContent(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        let selectedModel = Self.getSelectedModel()

        // gemini-2.5-flash는 사고(thinking) 토큰이 maxOutputTokens 예산을 소비하므로
        // 실제 출력 토큰보다 충분히 큰 예산 할당 (4배)
        let adjustedMaxTokens: Int
        let adjustedTimeout: TimeInterval
        if selectedModel == .gemini25Flash {
            adjustedMaxTokens = maxTokens * 4
            adjustedTimeout = 120  // 사고 시간 고려
        } else {
            adjustedMaxTokens = maxTokens
            adjustedTimeout = 60
        }

        logger.info("💎 [Google] generateContent 시작 - model: \(selectedModel.displayName), maxTokens: \(maxTokens) → \(adjustedMaxTokens)")

        let fullPrompt = "\(systemPrompt)\n\n\(userPrompt)"

        let request = try await buildGeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: fullPrompt)])],
            generationConfig: GeminiGenerationConfig(
                temperature: temperature,
                maxOutputTokens: adjustedMaxTokens
            ),
            timeoutInterval: adjustedTimeout
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200:
                let responseBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.info("💎 [Google] generateContent 응답 (처음 500자): \(String(responseBody.prefix(500)))")

                do {
                    let result = try decodeGeminiResponse(from: data)
                    guard let text = result.candidates?.first?.content.parts.first?.text else {
                        logger.error("💎 [Google] generateContent 파싱 실패 - candidates nil 또는 text 없음")
                        throw AIServiceError.invalidResponse
                    }
                    logger.info("💎 [Google] generateContent 성공 - \(text.count)자")
                    return text
                } catch {
                    logger.error("💎 [Google] JSON 디코딩 실패: \(error.localizedDescription)")
                    logger.error("💎 [Google] 원본 응답: \(String(responseBody.prefix(1000)))")
                    throw AIServiceError.decodingError
                }
            case 400, 401, 403:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] generateContent 실패 - status: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.invalidAPIKey
            case 429:
                throw AIServiceError.rateLimitExceeded
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] generateContent 서버 오류 - status: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Content with Images (멀티모달)

    func generateContentWithImages(
        systemPrompt: String,
        userPrompt: String,
        images: [AIImageData],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        let selectedModel = Self.getSelectedModel()

        let adjustedMaxTokens: Int
        let adjustedTimeout: TimeInterval
        if selectedModel == .gemini25Flash {
            adjustedMaxTokens = maxTokens * 4
            adjustedTimeout = 120
        } else {
            adjustedMaxTokens = maxTokens
            adjustedTimeout = 60
        }

        logger.info("💎 [Google] generateContentWithImages 시작 - model: \(selectedModel.displayName), images: \(images.count)장, maxTokens: \(maxTokens) → \(adjustedMaxTokens)")

        // 멀티모달 parts 구성: 텍스트 + 이미지들
        var parts: [GeminiPart] = []
        parts.append(GeminiPart(text: "\(systemPrompt)\n\n\(userPrompt)"))

        for (index, image) in images.enumerated() {
            let base64 = image.data.base64EncodedString()
            parts.append(GeminiPart(mimeType: image.mimeType, data: base64))
            logger.info("💎 [Google] 이미지 \(index + 1) 추가 - \(image.mimeType), \(image.data.count) bytes")
        }

        let request = try await buildGeminiRequest(
            contents: [GeminiContent(parts: parts)],
            generationConfig: GeminiGenerationConfig(
                temperature: temperature,
                maxOutputTokens: adjustedMaxTokens
            ),
            timeoutInterval: adjustedTimeout
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200:
                let result = try decodeGeminiResponse(from: data)
                guard let text = result.candidates?.first?.content.parts.first?.text else {
                    logger.error("💎 [Google] generateContentWithImages 파싱 실패")
                    throw AIServiceError.invalidResponse
                }
                logger.info("💎 [Google] generateContentWithImages 성공 - \(text.count)자")
                return text
            case 400, 401, 403:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] generateContentWithImages 실패 - status: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.invalidAPIKey
            case 429:
                throw AIServiceError.rateLimitExceeded
            default:
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                logger.error("💎 [Google] generateContentWithImages 서버 오류 - status: \(httpResponse.statusCode), body: \(errorBody)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Response Decoder

    /// Cloud Code API / 표준 API 양쪽 응답 포맷을 모두 처리
    /// - Cloud Code: `{ "response": { "candidates": [...] } }`
    /// - Standard:   `{ "candidates": [...] }`
    private func decodeGeminiResponse(from data: Data) throws -> GeminiResponse {
        // Cloud Code API 래핑 응답 먼저 시도
        if let wrapped = try? JSONDecoder().decode(CloudCodeResponse.self, from: data) {
            logger.info("💎 [Google] Cloud Code 래핑 응답 디코딩 성공")
            return wrapped.response
        }
        // 표준 Gemini API 응답
        return try JSONDecoder().decode(GeminiResponse.self, from: data)
    }

    // MARK: - Private Helpers

    private var systemPrompt: String {
        """
        당신은 여행 스토리 작가입니다. 사용자의 여행 데이터를 바탕으로 따뜻하고 감성적인 여행 스토리를 작성해 주세요.

        규칙:
        1. 한국어로 작성합니다.
        2. 1인칭 시점으로 작성합니다.
        3. 장소와 시간 정보를 자연스럽게 녹여냅니다.
        4. 감정과 경험을 풍부하게 표현합니다.
        5. 200-400자 사이로 작성합니다.
        """
    }

    private func buildPrompt(from data: TravelStoryInput) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 M월 d일"
        dateFormatter.locale = Locale(identifier: "ko_KR")

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var placesDescription = ""
        for (index, place) in data.places.enumerated() {
            let time = timeFormatter.string(from: place.visitTime)
            placesDescription += "\(index + 1). \(time) - \(place.name) (\(place.activityType))\n"
        }

        return """
        여행 제목: \(data.title)
        여행 기간: \(dateFormatter.string(from: data.startDate)) ~ \(dateFormatter.string(from: data.endDate))
        총 이동 거리: \(String(format: "%.1f", data.totalDistance))km
        촬영한 사진: \(data.photoCount)장

        방문 장소:
        \(placesDescription)

        위 여행 정보를 바탕으로 감성적인 여행 스토리를 작성해 주세요.
        """
    }
}

// MARK: - Gemini API Models

/// Cloud Code Assist API용 래핑 요청
/// - model과 project가 최상위, 실제 요청은 request 필드 안에 래핑
private struct CloudCodeRequest: Encodable {
    let model: String
    let project: String
    let request: GeminiRequest
}

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]

    init(role: String? = "user", parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
}

private struct GeminiPart: Codable {
    let text: String?
    let inlineData: InlineData?

    struct InlineData: Codable {
        let mimeType: String  // "image/jpeg"
        let data: String      // base64
    }

    /// 텍스트 전용 이니셜라이저
    init(text: String) {
        self.text = text
        self.inlineData = nil
    }

    /// 이미지 전용 이니셜라이저
    init(mimeType: String, data: String) {
        self.text = nil
        self.inlineData = InlineData(mimeType: mimeType, data: data)
    }
}

private struct GeminiGenerationConfig: Encodable {
    var temperature: Double?
    var maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: GeminiContent
    }
}

/// Cloud Code Assist API 응답 래퍼
/// - Cloud Code API는 `{ "response": { "candidates": [...] } }` 형태로 응답을 래핑
private struct CloudCodeResponse: Decodable {
    let response: GeminiResponse
}
