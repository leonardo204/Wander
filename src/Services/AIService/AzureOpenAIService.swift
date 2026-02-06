import Foundation
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "AzureOpenAIService")

/// Azure OpenAI API 서비스
final class AzureOpenAIService: AIServiceProtocol {
    let provider: AIProvider = .azure

    // Azure OpenAI 설정 (UserDefaults에서 로드)
    private var endpoint: String {
        UserDefaults.standard.string(forKey: "azure_openai_endpoint") ?? ""
    }

    private var deploymentName: String {
        UserDefaults.standard.string(forKey: "azure_openai_deployment") ?? ""
    }

    private var apiVersion: String {
        UserDefaults.standard.string(forKey: "azure_openai_api_version") ?? "2024-02-15-preview"
    }

    private var apiKey: String? {
        try? KeychainManager.shared.getAPIKey(for: .azure)
    }

    // MARK: - Test Connection

    func testConnection() async throws -> Bool {
        logger.info("☁️ [Azure] testConnection 시작")

        guard let apiKey = apiKey else {
            logger.error("☁️ [Azure] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        guard !endpoint.isEmpty, !deploymentName.isEmpty else {
            logger.error("☁️ [Azure] Endpoint 또는 Deployment 미설정")
            throw AIServiceError.invalidConfiguration
        }

        let urlString = "\(endpoint)/openai/deployments/\(deploymentName)/chat/completions?api-version=\(apiVersion)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidConfiguration
        }

        let requestBody = AzureOpenAIRequest(
            messages: [
                AzureMessage(role: "user", content: "Hi")
            ],
            maxTokens: 10
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                logger.info("☁️ [Azure] 연결 테스트 성공")
                return true
            case 401:
                logger.error("☁️ [Azure] 401 - 잘못된 API 키")
                throw AIServiceError.invalidAPIKey
            case 404:
                logger.error("☁️ [Azure] 404 - 잘못된 Endpoint 또는 Deployment")
                throw AIServiceError.invalidConfiguration
            case 429:
                logger.error("☁️ [Azure] 429 - Rate limit")
                throw AIServiceError.rateLimitExceeded
            default:
                logger.error("☁️ [Azure] 서버 오류: \(httpResponse.statusCode)")
                throw AIServiceError.serverError(httpResponse.statusCode)
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error("☁️ [Azure] 네트워크 오류: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }

    // MARK: - Generate Story

    func generateStory(from travelData: TravelStoryInput) async throws -> String {
        logger.info("☁️ [Azure] generateStory 시작 - places: \(travelData.places.count)개")

        guard let apiKey = apiKey else {
            logger.error("☁️ [Azure] API 키 없음")
            throw AIServiceError.noAPIKey
        }

        guard !endpoint.isEmpty, !deploymentName.isEmpty else {
            logger.error("☁️ [Azure] Endpoint 또는 Deployment 미설정")
            throw AIServiceError.invalidConfiguration
        }

        let prompt = buildPrompt(from: travelData)
        let urlString = "\(endpoint)/openai/deployments/\(deploymentName)/chat/completions?api-version=\(apiVersion)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidConfiguration
        }

        let requestBody = AzureOpenAIRequest(
            messages: [
                AzureMessage(role: "system", content: systemPrompt),
                AzureMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: 1000
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(AzureOpenAIResponse.self, from: data)
                guard let content = result.choices.first?.message.content else {
                    logger.error("☁️ [Azure] 응답 파싱 실패 - content 없음")
                    throw AIServiceError.invalidResponse
                }
                logger.info("☁️ [Azure] 스토리 생성 성공 - length: \(content.count)자")
                return content

            case 401:
                throw AIServiceError.invalidAPIKey
            case 404:
                throw AIServiceError.invalidConfiguration
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
        logger.info("☁️ [Azure] generateContent 시작 - maxTokens: \(maxTokens)")

        guard let apiKey = apiKey else {
            throw AIServiceError.noAPIKey
        }

        guard !endpoint.isEmpty, !deploymentName.isEmpty else {
            throw AIServiceError.invalidConfiguration
        }

        let urlString = "\(endpoint)/openai/deployments/\(deploymentName)/chat/completions?api-version=\(apiVersion)"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidConfiguration
        }

        let requestBody = AzureOpenAIRequest(
            messages: [
                AzureMessage(role: "system", content: systemPrompt),
                AzureMessage(role: "user", content: userPrompt)
            ],
            temperature: temperature,
            maxTokens: maxTokens
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
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
                let result = try JSONDecoder().decode(AzureOpenAIResponse.self, from: data)
                guard let content = result.choices.first?.message.content else {
                    throw AIServiceError.invalidResponse
                }
                logger.info("☁️ [Azure] generateContent 성공 - \(content.count)자")
                return content
            case 401:
                throw AIServiceError.invalidAPIKey
            case 404:
                throw AIServiceError.invalidConfiguration
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

    // MARK: - Static Settings Helpers

    static func saveSettings(endpoint: String, deploymentName: String, apiVersion: String) {
        UserDefaults.standard.set(endpoint, forKey: "azure_openai_endpoint")
        UserDefaults.standard.set(deploymentName, forKey: "azure_openai_deployment")
        UserDefaults.standard.set(apiVersion, forKey: "azure_openai_api_version")
        logger.info("☁️ [Azure] 설정 저장 완료")
    }

    static func getSettings() -> (endpoint: String, deploymentName: String, apiVersion: String) {
        let endpoint = UserDefaults.standard.string(forKey: "azure_openai_endpoint") ?? ""
        let deploymentName = UserDefaults.standard.string(forKey: "azure_openai_deployment") ?? ""
        let apiVersion = UserDefaults.standard.string(forKey: "azure_openai_api_version") ?? "2024-02-15-preview"
        return (endpoint, deploymentName, apiVersion)
    }

    static var isConfigured: Bool {
        let settings = getSettings()
        return !settings.endpoint.isEmpty && !settings.deploymentName.isEmpty
    }
}

// MARK: - Azure OpenAI API Models

private struct AzureOpenAIRequest: Encodable {
    let messages: [AzureMessage]
    var temperature: Double?
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct AzureMessage: Codable {
    let role: String
    let content: String
}

private struct AzureOpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: AzureMessage
    }
}
