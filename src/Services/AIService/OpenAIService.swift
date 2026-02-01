import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "OpenAIService")

/// OpenAI 모델 목록
enum OpenAIModel: String, CaseIterable, Identifiable {
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        }
    }

    var description: String {
        switch self {
        case .gpt4o: return "최고 성능, 더 높은 비용"
        case .gpt4oMini: return "균형잡힌 성능, 저렴한 비용"
        }
    }

    var storyMaxTokens: Int {
        switch self {
        case .gpt4o: return 1024
        case .gpt4oMini: return 800
        }
    }

    var storyTemperature: Double {
        switch self {
        case .gpt4o: return 0.8
        case .gpt4oMini: return 0.7
        }
    }
}

/// OpenAI GPT API 서비스
final class OpenAIService: AIServiceProtocol {
    let provider: AIProvider = .openai

    private let baseURL = "https://api.openai.com/v1"

    private var model: String {
        Self.getSelectedModel().rawValue
    }

    private var apiKey: String? {
        try? KeychainManager.shared.getAPIKey(for: .openai)
    }

    // MARK: - Model Selection

    private static let modelKey = "openai_model"

    static func getSelectedModel() -> OpenAIModel {
        if let rawValue = UserDefaults.standard.string(forKey: modelKey),
           let model = OpenAIModel(rawValue: rawValue) {
            return model
        }
        return .gpt4oMini  // 기본값: 비용 효율적
    }

    static func setSelectedModel(_ model: OpenAIModel) {
        UserDefaults.standard.set(model.rawValue, forKey: modelKey)
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        logger.info("🤖 [OpenAI] testConnection 시작")
        guard let apiKey = apiKey else {
            logger.error("🤖 [OpenAI] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        let url = URL(string: "\(baseURL)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                logger.info("🤖 [OpenAI] 연결 테스트 성공")
                return true
            case 429:
                // Rate limit은 키가 유효함을 의미
                logger.info("🤖 [OpenAI] 429 - Rate limit (키 유효)")
                return true
            case 401:
                logger.error("🤖 [OpenAI] 401 - 잘못된 API 키")
                throw AIServiceError.invalidAPIKey
            default:
                logger.error("🤖 [OpenAI] 서버 오류: \(httpResponse.statusCode)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error("🤖 [OpenAI] 네트워크 오류: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Story

    func generateStory(from travelData: TravelStoryInput) async throws -> String {
        let selectedModel = Self.getSelectedModel()
        logger.info("🤖 [OpenAI] generateStory 시작 - model: \(selectedModel.displayName), places: \(travelData.places.count)개")

        guard let apiKey = apiKey else {
            logger.error("🤖 [OpenAI] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        let prompt = buildPrompt(from: travelData)
        let requestBody = OpenAIRequest(
            model: model,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: prompt)
            ],
            temperature: selectedModel.storyTemperature,
            maxTokens: selectedModel.storyMaxTokens
        )

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                guard let content = result.choices.first?.message.content else {
                    logger.error("🤖 [OpenAI] 응답 파싱 실패 - content 없음")
                    throw AIServiceError.invalidResponse
                }
                logger.info("🤖 [OpenAI] 스토리 생성 성공 - length: \(content.count)자")
                return content

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

// MARK: - OpenAI API Models

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct Message: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }
}
