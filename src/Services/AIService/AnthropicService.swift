import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AnthropicService")

/// Anthropic Claude 모델 목록
enum AnthropicModel: String, CaseIterable, Identifiable {
    case claude35Sonnet = "claude-3-5-sonnet-20241022"
    case claude3Haiku = "claude-3-haiku-20240307"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude35Sonnet: return "Claude 3.5 Sonnet"
        case .claude3Haiku: return "Claude 3 Haiku"
        }
    }

    var description: String {
        switch self {
        case .claude35Sonnet: return "최고 성능, 뛰어난 글쓰기"
        case .claude3Haiku: return "빠른 응답, 저렴한 비용"
        }
    }

    var storyMaxTokens: Int {
        switch self {
        case .claude35Sonnet: return 1024
        case .claude3Haiku: return 600
        }
    }
}

/// Anthropic Claude API 서비스
final class AnthropicService: AIServiceProtocol {
    let provider: AIProvider = .anthropic

    private let baseURL = "https://api.anthropic.com/v1"
    private let apiVersion = "2023-06-01"

    private var model: String {
        Self.getSelectedModel().rawValue
    }

    private var apiKey: String? {
        try? KeychainManager.shared.getAPIKey(for: .anthropic)
    }

    // MARK: - Model Selection

    private static let modelKey = "anthropic_model"

    static func getSelectedModel() -> AnthropicModel {
        if let rawValue = UserDefaults.standard.string(forKey: modelKey),
           let model = AnthropicModel(rawValue: rawValue) {
            return model
        }
        return .claude35Sonnet  // 기본값: 최고 성능
    }

    static func setSelectedModel(_ model: AnthropicModel) {
        UserDefaults.standard.set(model.rawValue, forKey: modelKey)
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        logger.info("🧠 [Anthropic] testConnection 시작 - model: \(self.model)")
        guard let apiKey = apiKey else {
            logger.error("🧠 [Anthropic] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        // 최소 토큰으로 연결 테스트 (비용 절약)
        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: 1,
            messages: [
                AnthropicMessage(role: "user", content: "1")
            ]
        )

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                logger.info("🧠 [Anthropic] 연결 테스트 성공")
                return true
            case 429:
                // Rate limit은 키가 유효함을 의미
                logger.info("🧠 [Anthropic] 429 - Rate limit (키 유효)")
                return true
            case 401:
                logger.error("🧠 [Anthropic] 401 - 잘못된 API 키")
                throw AIServiceError.invalidAPIKey
            default:
                logger.error("🧠 [Anthropic] 서버 오류: \(httpResponse.statusCode)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error("🧠 [Anthropic] 네트워크 오류: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Story

    func generateStory(from travelData: TravelStoryInput) async throws -> String {
        let selectedModel = Self.getSelectedModel()
        logger.info("🧠 [Anthropic] generateStory 시작 - model: \(selectedModel.displayName), places: \(travelData.places.count)개")

        guard let apiKey = apiKey else {
            logger.error("🧠 [Anthropic] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        let prompt = buildPrompt(from: travelData)
        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: selectedModel.storyMaxTokens,
            system: systemPrompt,
            messages: [
                AnthropicMessage(role: "user", content: prompt)
            ]
        )

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
                guard let textContent = result.content.first(where: { $0.type == "text" }),
                      let text = textContent.text else {
                    logger.error("🧠 [Anthropic] 응답 파싱 실패 - text 없음")
                    throw AIServiceError.invalidResponse
                }
                logger.info("🧠 [Anthropic] 스토리 생성 성공 - length: \(text.count)자")
                return text

            case 401:
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
        logger.info("🧠 [Anthropic] generateContent 시작 - maxTokens: \(maxTokens)")

        guard let apiKey = apiKey else {
            throw AIServiceError.noAPIKey
        }

        let requestBody = AnthropicRequest(
            model: model,
            maxTokens: maxTokens,
            system: systemPrompt,
            messages: [
                AnthropicMessage(role: "user", content: userPrompt)
            ]
        )

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
                guard let textContent = result.content.first(where: { $0.type == "text" }),
                      let text = textContent.text else {
                    throw AIServiceError.invalidResponse
                }
                logger.info("🧠 [Anthropic] generateContent 성공 - \(text.count)자")
                return text
            case 401:
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

// MARK: - Anthropic API Models

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    var system: String?
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}
