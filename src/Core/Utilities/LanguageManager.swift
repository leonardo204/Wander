import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "LanguageManager")

/// 앱 내 언어 설정을 관리하는 싱글톤
@MainActor
@Observable
class LanguageManager {
    static let shared = LanguageManager()

    /// 지원하는 언어 목록
    enum Language: String, CaseIterable, Identifiable {
        case system = "system"  // 시스템 설정 따르기
        case korean = "ko"
        case english = "en"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return "시스템 설정"
            case .korean: return "한국어"
            case .english: return "English"
            }
        }

        var localizedDisplayName: String {
            switch self {
            case .system:
                return String(localized: "settings.language.system")
            case .korean:
                return "한국어"
            case .english:
                return "English"
            }
        }

        var flag: String {
            switch self {
            case .system: return "🌐"
            case .korean: return "🇰🇷"
            case .english: return "🇺🇸"
            }
        }
    }

    /// 현재 선택된 언어
    var currentLanguage: Language {
        didSet {
            saveLanguageSetting()
            updateBundle()
            logger.info("🌐 [Language] 언어 변경: \(oldValue.rawValue) → \(self.currentLanguage.rawValue)")
        }
    }

    /// 실제 적용되는 언어 코드
    var effectiveLanguageCode: String {
        switch currentLanguage {
        case .system:
            return Locale.current.language.languageCode?.identifier ?? "ko"
        case .korean:
            return "ko"
        case .english:
            return "en"
        }
    }

    /// 현재 사용 중인 Bundle (로컬라이즈용)
    private(set) var bundle: Bundle = .main

    private let languageKey = "wander_app_language"

    private init() {
        // 저장된 설정 로드
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = Language(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .system
        }
        updateBundle()
        logger.info("🌐 [Language] 초기화 완료 - 현재 언어: \(self.currentLanguage.displayName)")
    }

    private func saveLanguageSetting() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }

    private func updateBundle() {
        let languageCode = effectiveLanguageCode

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = .main
        }
    }

    /// 로컬라이즈된 문자열 반환
    func localizedString(_ key: String) -> String {
        // iOS 17+에서는 String Catalog를 자동으로 사용
        // 앱 내 언어 설정을 위해 수동으로 처리
        if currentLanguage == .system {
            return String(localized: String.LocalizationValue(key))
        } else {
            return bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        }
    }
}

// MARK: - String Extension for Localization
extension String {
    /// 로컬라이즈된 문자열 반환 (MainActor에서 호출)
    @MainActor
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    /// 포맷 문자열 로컬라이즈 (MainActor에서 호출)
    @MainActor
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.localizedString(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - View Extension
extension View {
    /// 언어 변경 시 뷰 갱신을 위한 modifier
    func observeLanguageChange() -> some View {
        self.id(LanguageManager.shared.currentLanguage.rawValue)
    }
}
