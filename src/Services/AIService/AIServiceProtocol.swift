import Foundation

// MARK: - AI Provider Enum

enum AIProvider: String, CaseIterable, Identifiable {
    case openai
    case anthropic
    case google
    case azure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google Gemini"
        case .azure: return "Azure OpenAI"
        }
    }

    var description: String {
        switch self {
        case .openai: return "GPT-4o, GPT-4 Turbo"
        case .anthropic: return "Claude 3.5 Sonnet"
        case .google: return "Gemini Pro, Gemini Flash"
        case .azure: return "Azure 호스팅 OpenAI"
        }
    }

    var keychainType: KeychainManager.APIKeyType {
        switch self {
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .google: return .google
        case .azure: return .azure
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
        case .azure:
            return URL(string: "https://portal.azure.com/")
        }
    }

    /// Azure OpenAI는 추가 설정이 필요
    var requiresAdditionalConfig: Bool {
        self == .azure
    }
}

// MARK: - AI Image Data

/// 멀티모달 API에 전달할 이미지 데이터
struct AIImageData {
    let data: Data        // JPEG 바이너리
    let mimeType: String  // "image/jpeg"
}

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    var provider: AIProvider { get }

    /// API 키 유효성 테스트
    func testConnection() async throws -> Bool

    /// 여행 스토리 생성
    func generateStory(from travelData: TravelStoryInput) async throws -> String

    /// 범용 콘텐츠 생성 (AI 다듬기 등에서 사용)
    func generateContent(
        systemPrompt: String,
        userPrompt: String,
        maxTokens: Int,
        temperature: Double
    ) async throws -> String

    /// 멀티모달 콘텐츠 생성 (이미지 + 텍스트)
    /// 기본 구현: 이미지 무시하고 텍스트만 전송 (비멀티모달 프로바이더용 폴백)
    func generateContentWithImages(
        systemPrompt: String,
        userPrompt: String,
        images: [AIImageData],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String
}

// MARK: - Default Multimodal Fallback

extension AIServiceProtocol {
    /// 멀티모달 미지원 프로바이더: 이미지 무시, 텍스트만 전송
    func generateContentWithImages(
        systemPrompt: String,
        userPrompt: String,
        images: [AIImageData],
        maxTokens: Int,
        temperature: Double
    ) async throws -> String {
        return try await generateContent(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }
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
    case invalidConfiguration
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
        case .invalidConfiguration:
            return "서비스 설정이 올바르지 않습니다. Endpoint와 Deployment를 확인해 주세요."
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
        case .azure:
            return AzureOpenAIService()
        }
    }
}
