import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "GoogleAIService")

/// Google Gemini 모델 목록
enum GeminiModel: String, CaseIterable, Identifiable {
    case gemini2Flash = "gemini-2.0-flash"
    case gemini2FlashLite = "gemini-2.0-flash-lite"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini2Flash: return "Gemini 2.0 Flash"
        case .gemini2FlashLite: return "Gemini 2.0 Flash Lite"
        case .gemini15Pro: return "Gemini 1.5 Pro"
        case .gemini15Flash: return "Gemini 1.5 Flash"
        }
    }

    var description: String {
        switch self {
        case .gemini2Flash: return "최신 모델, 빠르고 정확"
        case .gemini2FlashLite: return "경량 모델, 더 빠른 응답"
        case .gemini15Pro: return "고성능 모델"
        case .gemini15Flash: return "균형잡힌 성능"
        }
    }

    /// 스토리 생성 시 권장 최대 출력 토큰
    var storyMaxTokens: Int {
        switch self {
        case .gemini2Flash: return 1024      // 충분한 스토리 길이
        case .gemini2FlashLite: return 512   // 경량 모델은 짧게
        case .gemini15Pro: return 1024       // 고성능
        case .gemini15Flash: return 800      // 균형
        }
    }

    /// 스토리 생성 temperature (창의성 조절)
    var storyTemperature: Double {
        switch self {
        case .gemini2Flash: return 0.7
        case .gemini2FlashLite: return 0.6   // 경량 모델은 더 일관되게
        case .gemini15Pro: return 0.8        // 고성능은 더 창의적으로
        case .gemini15Flash: return 0.7
        }
    }
}

/// Google Gemini API 서비스
final class GoogleAIService: AIServiceProtocol {
    let provider: AIProvider = .google

    private var model: String {
        Self.getSelectedModel().rawValue
    }

    private var apiKey: String? {
        try? KeychainManager.shared.getAPIKey(for: .google)
    }

    private var baseURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model)"
    }

    // MARK: - Model Selection

    private static let modelKey = "google_gemini_model"

    static func getSelectedModel() -> GeminiModel {
        if let rawValue = UserDefaults.standard.string(forKey: modelKey),
           let model = GeminiModel(rawValue: rawValue) {
            return model
        }
        return .gemini2Flash  // 기본값
    }

    static func setSelectedModel(_ model: GeminiModel) {
        UserDefaults.standard.set(model.rawValue, forKey: modelKey)
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        logger.info("💎 [Google] testConnection 시작 - model: \(self.model)")
        guard let apiKey = apiKey else {
            logger.error("💎 [Google] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        let url = URL(string: "\(baseURL):generateContent")!

        // 연결 테스트는 최소 토큰만 사용 (비용/한도 절약)
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [GeminiPart(text: "1")])  // 최소 입력
            ],
            generationConfig: GeminiGenerationConfig(maxOutputTokens: 1)  // 최소 출력
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                logger.info("💎 [Google] 연결 테스트 성공")
                return true
            case 429:
                // Rate limit은 키가 유효함을 의미 - 성공으로 처리
                logger.info("💎 [Google] 429 - Rate limit (키 유효, 요청 제한)")
                return true
            case 400:
                logger.error("💎 [Google] 400 - 잘못된 요청")
                throw AIServiceError.invalidAPIKey
            case 403:
                logger.error("💎 [Google] 403 - 권한 없음 또는 잘못된 API 키")
                throw AIServiceError.invalidAPIKey
            default:
                logger.error("💎 [Google] 서버 오류: \(httpResponse.statusCode)")
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
        logger.info("💎 [Google] generateStory 시작 - model: \(selectedModel.displayName), places: \(travelData.places.count)개, maxTokens: \(selectedModel.storyMaxTokens)")

        guard let apiKey = apiKey else {
            logger.error("💎 [Google] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        let prompt = buildPrompt(from: travelData)
        let fullPrompt = "\(systemPrompt)\n\n\(prompt)"

        let url = URL(string: "\(baseURL):generateContent")!

        // 모델별 최적화된 설정 사용
        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [GeminiPart(text: fullPrompt)])
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: selectedModel.storyTemperature,
                maxOutputTokens: selectedModel.storyMaxTokens
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
                guard let text = result.candidates?.first?.content.parts.first?.text else {
                    logger.error("💎 [Google] 응답 파싱 실패 - text 없음")
                    throw AIServiceError.invalidResponse
                }
                logger.info("💎 [Google] 스토리 생성 성공 - length: \(text.count)자")
                return text

            case 400, 403:
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
        logger.info("💎 [Google] generateContent 시작 - maxTokens: \(maxTokens)")

        guard let apiKey = apiKey else {
            throw AIServiceError.noAPIKey
        }

        let fullPrompt = "\(systemPrompt)\n\n\(userPrompt)"
        let url = URL(string: "\(baseURL):generateContent")!

        let requestBody = GeminiRequest(
            contents: [
                GeminiContent(parts: [GeminiPart(text: fullPrompt)])
            ],
            generationConfig: GeminiGenerationConfig(
                temperature: temperature,
                maxOutputTokens: maxTokens
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(GeminiResponse.self, from: data)
                guard let text = result.candidates?.first?.content.parts.first?.text else {
                    throw AIServiceError.invalidResponse
                }
                logger.info("💎 [Google] generateContent 성공 - \(text.count)자")
                return text
            case 400, 403:
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

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
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
