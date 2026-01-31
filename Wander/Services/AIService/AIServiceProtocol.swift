import Foundation

// MARK: - AI Provider Enum

enum AIProvider: String, CaseIterable, Identifiable {
    case openai
    case anthropic
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google Gemini"
        }
    }

    var description: String {
        switch self {
        case .openai: return "GPT-4o, GPT-4 Turbo"
        case .anthropic: return "Claude 3.5 Sonnet"
        case .google: return "Gemini Pro, Gemini Flash"
        }
    }

    var keychainType: KeychainManager.APIKeyType {
        switch self {
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .google: return .google
        }
    }

    var websiteURL: URL? {
        switch self {
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/")
        case .google:
            return URL(string: "https://aistudio.google.com/app/apikey")
        }
    }
}

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    var provider: AIProvider { get }

    /// API 키 유효성 테스트
    func testConnection() async throws -> Bool

    /// 여행 스토리 생성
    func generateStory(from travelData: TravelStoryInput) async throws -> String
}

// MARK: - Travel Story Input

struct TravelStoryInput {
    let title: String
    let startDate: Date
    let endDate: Date
    let places: [PlaceSummary]
    let totalDistance: Double
    let photoCount: Int

    struct PlaceSummary {
        let name: String
        let address: String
        let activityType: String
        let visitTime: Date
        let photoCount: Int
    }
}

// MARK: - AI Service Errors

enum AIServiceError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case rateLimitExceeded
    case serverError(Int)
    case invalidResponse
    case decodingError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API 키가 설정되지 않았습니다."
        case .invalidAPIKey:
            return "API 키가 유효하지 않습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "API 요청 한도를 초과했습니다. 잠시 후 다시 시도해 주세요."
        case .serverError(let code):
            return "서버 오류가 발생했습니다. (코드: \(code))"
        case .invalidResponse:
            return "응답을 처리할 수 없습니다."
        case .decodingError:
            return "응답 파싱 중 오류가 발생했습니다."
        }
    }
}

// MARK: - AI Service Factory

final class AIServiceFactory {
    static func createService(for provider: AIProvider) -> AIServiceProtocol {
        switch provider {
        case .openai:
            return OpenAIService()
        case .anthropic:
            return AnthropicService()
        case .google:
            return GoogleAIService()
        }
    }
}
