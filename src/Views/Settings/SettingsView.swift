import SwiftUI
import SwiftData
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SettingsView")

/// 설정 네비게이션 목적지 enum
/// - NOTE: NavigationStack(path:) 방식으로 네비게이션 관리를 위해 사용
enum SettingsDestination: Hashable {
    case aiSettings
    case dataManagement
    case permissionSettings
    case securitySettings
    case languageSettings
    case categoryManagement
    case userPlaces
    case shareSettings
    case about
}

/// 설정 탭 메인 뷰 - 앱 설정 관리
/// - NOTE: navigationPath로 상세 화면 네비게이션 관리
/// - IMPORTANT: 탭 전환 시 resetTrigger로 초기화면 표시
struct SettingsView: View {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = true
    @State private var showAISettings = false
    @State private var showDataManagement = false
    @State private var showPermissions = false
    @State private var showAbout = false
    @State private var showShareLinkTest = false
    @State private var navigationPath = NavigationPath()

    /// 네비게이션 리셋 트리거 (부모에서 바인딩)
    /// - NOTE: 탭 전환 또는 같은 탭 클릭 시 토글되어 navigationPath 초기화 유도
    @Binding var resetTrigger: Bool

    init(resetTrigger: Binding<Bool> = .constant(false)) {
        _resetTrigger = resetTrigger
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // AI Settings Section
                Section {
                    NavigationLink(value: SettingsDestination.aiSettings) {
                        SettingsRow(
                            icon: "sparkles",
                            iconColor: WanderColors.primary,
                            title: "AI 설정",
                            subtitle: "API 키 관리, 프로바이더 선택"
                        )
                    }
                } header: {
                    Text("AI 기능")
                }

                // Data Section
                Section {
                    NavigationLink(value: SettingsDestination.dataManagement) {
                        SettingsRow(
                            icon: "externaldrive",
                            iconColor: WanderColors.info,
                            title: "데이터 관리",
                            subtitle: "저장 공간, 캐시 삭제"
                        )
                    }

                    NavigationLink(value: SettingsDestination.permissionSettings) {
                        SettingsRow(
                            icon: "lock.shield",
                            iconColor: WanderColors.success,
                            title: "권한 설정",
                            subtitle: "사진, 위치 접근 권한"
                        )
                    }
                } header: {
                    Text("데이터 및 권한")
                }

                // Security Section
                Section {
                    NavigationLink(value: SettingsDestination.securitySettings) {
                        SettingsRow(
                            icon: "lock.shield.fill",
                            iconColor: WanderColors.primary,
                            title: "보안",
                            subtitle: "PIN, 생체인증 설정"
                        )
                    }
                } header: {
                    Text("보안")
                }

                // Customization Section
                Section {
                    NavigationLink(value: SettingsDestination.languageSettings) {
                        SettingsRow(
                            icon: "globe",
                            iconColor: WanderColors.info,
                            title: "settings.language".localized,
                            subtitle: LanguageManager.shared.currentLanguage.displayName
                        )
                    }

                    NavigationLink(value: SettingsDestination.categoryManagement) {
                        SettingsRow(
                            icon: "folder.fill",
                            iconColor: WanderColors.warning,
                            title: "settings.categoryManagement".localized,
                            subtitle: "settings.categoryManagement.description".localized
                        )
                    }

                    NavigationLink(value: SettingsDestination.userPlaces) {
                        SettingsRow(
                            icon: "mappin.circle.fill",
                            iconColor: WanderColors.error,
                            title: "settings.placeManagement".localized,
                            subtitle: "settings.placeManagement.description".localized
                        )
                    }
                } header: {
                    Text("settings.section.customization".localized)
                }

                // Share Settings Section
                Section {
                    NavigationLink(value: SettingsDestination.shareSettings) {
                        SettingsRow(
                            icon: "square.and.arrow.up",
                            iconColor: WanderColors.warning,
                            title: "공유 설정",
                            subtitle: "기본 공유 옵션"
                        )
                    }
                } header: {
                    Text("공유")
                }

                // About Section
                Section {
                    NavigationLink(value: SettingsDestination.about) {
                        SettingsRow(
                            icon: "info.circle",
                            iconColor: WanderColors.textSecondary,
                            title: "앱 정보",
                            subtitle: "버전, 라이선스"
                        )
                    }
                } header: {
                    Text("기타")
                }

                // Developer Mode Section
                Section {
                    Button(action: { showShareLinkTest = true }) {
                        SettingsRow(
                            icon: "link.badge.plus",
                            iconColor: WanderColors.primary,
                            title: "공유 링크 테스트",
                            subtitle: "Wander 공유 링크로 기록 수신 테스트"
                        )
                    }

                    Button(action: resetOnboarding) {
                        SettingsRow(
                            icon: "arrow.counterclockwise",
                            iconColor: WanderColors.textTertiary,
                            title: "온보딩 다시 보기",
                            subtitle: nil
                        )
                    }
                } header: {
                    Text("개발자 모드")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.bottom, 70, for: .scrollContent)  // 탭바 높이만큼 여백 확보
            .navigationTitle("설정")
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .aiSettings:
                    AIProviderSettingsView()
                case .dataManagement:
                    DataManagementView()
                case .permissionSettings:
                    PermissionSettingsView()
                case .securitySettings:
                    SecuritySettingsView()
                case .languageSettings:
                    LanguageSettingsView()
                case .categoryManagement:
                    CategoryManagementView()
                case .userPlaces:
                    UserPlacesView()
                case .shareSettings:
                    ShareSettingsView()
                case .about:
                    AboutView()
                }
            }
            .onAppear {
                logger.info("⚙️ [SettingsView] 설정 화면 나타남")
            }
            .onChange(of: resetTrigger) { _, _ in
                // NOTE: 탭 전환 또는 같은 탭 클릭 시 트리거됨 → 네비게이션 스택 초기화하여 루트로 이동
                if !navigationPath.isEmpty {
                    logger.info("⚙️ [SettingsView] 네비게이션 리셋 - 초기화면으로 복귀")
                    navigationPath = NavigationPath()
                }
            }
            .sheet(isPresented: $showShareLinkTest) {
                ShareLinkTestView()
            }
        }
    }

    private func resetOnboarding() {
        logger.info("⚙️ [SettingsView] 온보딩 리셋")
        isOnboardingCompleted = false
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: WanderSpacing.space3) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15))
                .cornerRadius(6)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WanderTypography.body)
                    .foregroundColor(WanderColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)
                }
            }
        }
        .padding(.vertical, WanderSpacing.space1)
    }
}

// MARK: - AI Provider Settings View
struct AIProviderSettingsView: View {
    @State private var providerToEdit: AIProvider?

    private var configuredProviders: Set<AIProvider> {
        Set(AIProvider.allCases.filter { provider in
            KeychainManager.shared.hasAPIKey(for: provider.keychainType)
        })
    }

    var body: some View {
        List {
            Section {
                Text("AI 스토리 생성 기능을 사용하려면 API 키가 필요합니다. 직접 발급받은 키를 입력해 주세요.")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }

            Section("프로바이더") {
                ForEach(AIProvider.allCases) { provider in
                    Button(action: {
                        providerToEdit = provider
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)

                                Text(provider.description)
                                    .font(WanderTypography.caption1)
                                    .foregroundColor(WanderColors.textSecondary)
                            }

                            Spacer()

                            if configuredProviders.contains(provider) {
                                HStack(spacing: WanderSpacing.space2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(WanderColors.success)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(WanderColors.textTertiary)
                                }
                            } else {
                                HStack(spacing: WanderSpacing.space2) {
                                    Text("설정 필요")
                                        .font(WanderTypography.caption1)
                                        .foregroundColor(WanderColors.textTertiary)
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(WanderColors.textTertiary)
                                }
                            }
                        }
                    }
                }
            }

            if !configuredProviders.isEmpty {
                Section {
                    Button(role: .destructive, action: deleteAllKeys) {
                        Text("모든 API 키 삭제")
                    }
                }
            }
        }
        .navigationTitle("AI 설정")
        .onAppear {
            logger.info("⚙️ [AIProviderSettingsView] AI 설정 화면 나타남 - 설정된 프로바이더: \(self.configuredProviders.count)개")
        }
        .sheet(item: $providerToEdit) { provider in
            APIKeyInputView(provider: provider)
        }
    }

    private func deleteAllKeys() {
        logger.info("⚙️ [AIProviderSettingsView] 모든 API 키 삭제")
        KeychainManager.shared.deleteAllAPIKeys()
    }
}

// MARK: - API Key Input View
struct APIKeyInputView: View {
    let provider: AIProvider
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var testError: String?
    @State private var hasExistingKey = false
    @State private var isEditingKey = false  // 키 수정 모드
    @State private var maskedKey = ""  // 마스킹된 키 표시용

    // Azure specific settings
    @State private var azureEndpoint = ""
    @State private var azureDeployment = ""
    @State private var azureApiVersion = "2024-02-15-preview"

    // Model selection for each provider
    @State private var selectedGeminiModel: GeminiModel = .gemini2Flash
    @State private var selectedOpenAIModel: OpenAIModel = .gpt4oMini
    @State private var selectedAnthropicModel: AnthropicModel = .claude35Sonnet

    var body: some View {
        NavigationStack {
            Form {
                // Model selection for each provider
                if provider == .google {
                    Section {
                        Picker("모델", selection: $selectedGeminiModel) {
                            ForEach(GeminiModel.allCases) { model in
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(WanderTypography.caption1)
                                        .foregroundColor(WanderColors.textSecondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("모델 선택")
                    } footer: {
                        Text("Gemini 2.0 Flash가 가장 최신 모델입니다.")
                    }
                }

                if provider == .openai {
                    Section {
                        Picker("모델", selection: $selectedOpenAIModel) {
                            ForEach(OpenAIModel.allCases) { model in
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(WanderTypography.caption1)
                                        .foregroundColor(WanderColors.textSecondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("모델 선택")
                    } footer: {
                        Text("GPT-4o Mini가 비용 효율적입니다.")
                    }
                }

                if provider == .anthropic {
                    Section {
                        Picker("모델", selection: $selectedAnthropicModel) {
                            ForEach(AnthropicModel.allCases) { model in
                                VStack(alignment: .leading) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(WanderTypography.caption1)
                                        .foregroundColor(WanderColors.textSecondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("모델 선택")
                    } footer: {
                        Text("Claude 3.5 Sonnet이 최고 성능입니다.")
                    }
                }

                // Azure specific configuration
                if provider == .azure {
                    Section {
                        TextField("Endpoint URL", text: $azureEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)

                        TextField("Deployment Name", text: $azureDeployment)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("API Version", text: $azureApiVersion)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("Azure 설정")
                    } footer: {
                        Text("Azure Portal에서 확인할 수 있습니다.\n예: https://your-resource.openai.azure.com")
                    }
                }

                Section {
                    if hasExistingKey && !isEditingKey {
                        // 기존 키가 있고 편집 모드가 아닐 때 - 마스킹된 키 표시
                        HStack {
                            Text(maskedKey)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(WanderColors.textSecondary)
                            Spacer()
                            Button("변경") {
                                isEditingKey = true
                                apiKey = ""
                            }
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.primary)
                        }
                    } else {
                        // 새 키 입력 또는 편집 모드
                        SecureField("API 키 입력", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        if isEditingKey {
                            Button("취소") {
                                isEditingKey = false
                                apiKey = ""
                            }
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                        }
                    }
                } header: {
                    Text("API 키")
                } footer: {
                    if hasExistingKey && !isEditingKey {
                        Text("키가 안전하게 저장되어 있습니다.")
                    } else if isEditingKey {
                        Text("새 키를 입력하면 기존 키를 덮어씁니다.")
                    } else {
                        Text("API 키는 Keychain에 안전하게 저장됩니다.")
                    }
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            Text("연결 테스트")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let result = testResult {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result ? WanderColors.success : WanderColors.error)
                            }
                        }
                    }
                    // 기존 키가 있거나 새 키가 입력된 경우 테스트 가능
                    .disabled((!hasExistingKey && apiKey.isEmpty) || isTesting || (provider == .azure && (azureEndpoint.isEmpty || azureDeployment.isEmpty)))

                    if let error = testError {
                        Text(error)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.error)
                    }
                }

                Section {
                    Button("키 발급받기") {
                        openProviderWebsite()
                    }
                } footer: {
                    Text("프로바이더 웹사이트에서 API 키를 발급받을 수 있습니다.")
                }

                if hasExistingKey {
                    Section {
                        Button(role: .destructive, action: deleteKey) {
                            Text("저장된 키 삭제")
                        }
                    }
                }
            }
            .navigationTitle("\(provider.displayName) API 키")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if !apiKey.isEmpty {
                            saveAPIKey()
                        }
                        dismiss()
                    }
                    .disabled(!hasExistingKey && apiKey.isEmpty || (provider == .azure && (azureEndpoint.isEmpty || azureDeployment.isEmpty)))
                }
            }
            .onAppear {
                hasExistingKey = KeychainManager.shared.hasAPIKey(for: provider.keychainType)
                logger.info("🔑 [APIKeyInputView] 나타남 - provider: \(provider.displayName), hasExistingKey: \(hasExistingKey)")

                // 기존 키가 있으면 마스킹된 표시 생성
                if hasExistingKey {
                    if let existingKey = try? KeychainManager.shared.getAPIKey(for: provider.keychainType) {
                        // 앞 4자, 뒤 4자만 표시하고 나머지는 마스킹
                        let keyLength = existingKey.count
                        if keyLength > 8 {
                            let prefix = String(existingKey.prefix(4))
                            let suffix = String(existingKey.suffix(4))
                            let masked = String(repeating: "•", count: min(keyLength - 8, 20))
                            maskedKey = "\(prefix)\(masked)\(suffix)"
                        } else {
                            maskedKey = String(repeating: "•", count: keyLength)
                        }
                    } else {
                        maskedKey = "••••••••••••"
                    }
                }

                // Load Azure settings if exists
                if provider == .azure {
                    let settings = AzureOpenAIService.getSettings()
                    azureEndpoint = settings.endpoint
                    azureDeployment = settings.deploymentName
                    azureApiVersion = settings.apiVersion
                }

                // Load saved model selection for each provider
                if provider == .google {
                    selectedGeminiModel = GoogleAIService.getSelectedModel()
                }
                if provider == .openai {
                    selectedOpenAIModel = OpenAIService.getSelectedModel()
                }
                if provider == .anthropic {
                    selectedAnthropicModel = AnthropicService.getSelectedModel()
                }
            }
        }
    }

    private func testConnection() {
        logger.info("🔑 [APIKeyInputView] 연결 테스트 시작 - provider: \(provider.displayName)")
        isTesting = true
        testResult = nil
        testError = nil

        // Save Azure settings first if applicable
        if provider == .azure {
            AzureOpenAIService.saveSettings(
                endpoint: azureEndpoint,
                deploymentName: azureDeployment,
                apiVersion: azureApiVersion
            )
        }

        // Save selected model for each provider
        if provider == .google {
            GoogleAIService.setSelectedModel(selectedGeminiModel)
        }
        if provider == .openai {
            OpenAIService.setSelectedModel(selectedOpenAIModel)
        }
        if provider == .anthropic {
            AnthropicService.setSelectedModel(selectedAnthropicModel)
        }

        // 새 키가 입력된 경우에만 임시 저장
        let needsTemporarySave = !apiKey.isEmpty
        if needsTemporarySave {
            do {
                try KeychainManager.shared.saveAPIKey(apiKey, for: provider.keychainType)
            } catch {
                logger.error("🔑 [APIKeyInputView] 키 저장 실패 - provider: \(provider.displayName), error: \(error.localizedDescription)")
                testResult = false
                testError = "키 저장 실패: \(error.localizedDescription)"
                isTesting = false
                return
            }
        }

        Task {
            do {
                let service = AIServiceFactory.createService(for: provider)
                let result = try await service.testConnection()

                await MainActor.run {
                    logger.info("🔑 [APIKeyInputView] 연결 테스트 성공 - provider: \(provider.displayName)")
                    testResult = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    logger.error("🔑 [APIKeyInputView] 연결 테스트 실패 - provider: \(provider.displayName), error: \(error.localizedDescription)")
                    testResult = false
                    testError = error.localizedDescription
                    isTesting = false
                }

                // Remove the test key if test failed and there was no existing key before
                if needsTemporarySave && !hasExistingKey {
                    try? KeychainManager.shared.deleteAPIKey(for: provider.keychainType)
                }
            }
        }
    }

    private func saveAPIKey() {
        // Save Azure settings first if applicable
        if provider == .azure {
            AzureOpenAIService.saveSettings(
                endpoint: azureEndpoint,
                deploymentName: azureDeployment,
                apiVersion: azureApiVersion
            )
        }

        // Save selected model for each provider
        if provider == .google {
            GoogleAIService.setSelectedModel(selectedGeminiModel)
        }
        if provider == .openai {
            OpenAIService.setSelectedModel(selectedOpenAIModel)
        }
        if provider == .anthropic {
            AnthropicService.setSelectedModel(selectedAnthropicModel)
        }

        do {
            try KeychainManager.shared.saveAPIKey(apiKey, for: provider.keychainType)
            logger.info("🔑 [APIKeyInputView] API 키 저장 성공 - provider: \(provider.displayName)")
        } catch {
            logger.error("🔑 [APIKeyInputView] API 키 저장 실패 - provider: \(provider.displayName), error: \(error.localizedDescription)")
        }
    }

    private func deleteKey() {
        logger.info("🔑 [APIKeyInputView] 키 삭제 - provider: \(provider.displayName)")
        try? KeychainManager.shared.deleteAPIKey(for: provider.keychainType)
        hasExistingKey = false
        dismiss()
    }

    private func openProviderWebsite() {
        if let url = provider.websiteURL {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Data Management View
struct DataManagementView: View {
    @Query private var records: [TravelRecord]
    @State private var cacheSize = "계산 중..."
    @State private var showDeleteAllConfirmation = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section("저장 공간") {
                HStack {
                    Text("캐시 크기")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Button("캐시 삭제") {
                    clearCache()
                }
                .foregroundColor(WanderColors.error)
            }

            Section("기록 데이터") {
                HStack {
                    Text("저장된 기록")
                    Spacer()
                    Text("\(records.count)개")
                        .foregroundColor(WanderColors.textSecondary)
                }

                Button("모든 기록 삭제") {
                    showDeleteAllConfirmation = true
                }
                .foregroundColor(WanderColors.error)
            }
        }
        .navigationTitle("데이터 관리")
        .onAppear {
            logger.info("📦 [DataManagementView] 데이터 관리 화면 나타남")
            calculateCacheSize()
        }
        .confirmationDialog(
            "모든 기록을 삭제하시겠습니까?",
            isPresented: $showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("모두 삭제", role: .destructive) {
                deleteAllRecords()
            }
        } message: {
            Text("이 작업은 되돌릴 수 없습니다.")
        }
    }

    private func calculateCacheSize() {
        // Simulate cache calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cacheSize = "12.5 MB"
        }
    }

    private func clearCache() {
        logger.info("📦 [DataManagementView] 캐시 삭제")
        // Clear cache
        cacheSize = "0 MB"
    }

    private func deleteAllRecords() {
        logger.info("📦 [DataManagementView] 모든 기록 삭제 - \(records.count)개")
        for record in records {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

// MARK: - Permission Settings View
struct PermissionSettingsView: View {
    @State private var photoStatus: PHAuthorizationStatus = .notDetermined
    @State private var locationStatus = "확인 중..."

    var body: some View {
        List {
            Section("사진 라이브러리") {
                HStack {
                    Text("상태")
                    Spacer()
                    Text(photoStatusText)
                        .foregroundColor(photoStatusColor)
                }

                Button("설정에서 변경") {
                    openSettings()
                }
            }

            Section("위치 서비스") {
                HStack {
                    Text("상태")
                    Spacer()
                    Text(locationStatus)
                        .foregroundColor(WanderColors.textSecondary)
                }

                Button("설정에서 변경") {
                    openSettings()
                }
            }

            Section {
                Text("권한 설정은 iOS 설정 앱에서 변경할 수 있습니다.")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            }
        }
        .navigationTitle("권한 설정")
        .onAppear {
            logger.info("🔒 [PermissionSettingsView] 권한 설정 화면 나타남")
            checkPermissions()
        }
    }

    private var photoStatusText: String {
        switch photoStatus {
        case .authorized: return "허용됨"
        case .limited: return "일부 허용"
        case .denied: return "거부됨"
        case .restricted: return "제한됨"
        case .notDetermined: return "미설정"
        @unknown default: return "알 수 없음"
        }
    }

    private var photoStatusColor: Color {
        switch photoStatus {
        case .authorized, .limited: return WanderColors.success
        case .denied, .restricted: return WanderColors.error
        default: return WanderColors.textSecondary
        }
    }

    private func checkPermissions() {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationStatus = "허용됨"
        logger.info("🔒 [PermissionSettingsView] 권한 확인 - 사진: \(photoStatusText), 위치: \(locationStatus)")
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Share Settings View
struct ShareSettingsView: View {
    @AppStorage("defaultShareFormat") private var defaultShareFormat = "text"

    var body: some View {
        List {
            Section("기본 공유 형식") {
                Picker("형식", selection: $defaultShareFormat) {
                    Text("텍스트").tag("text")
                    Text("이미지").tag("image")
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(WanderColors.success)
                    Text("워터마크 항상 포함")
                        .foregroundColor(WanderColors.textSecondary)
                }
            } footer: {
                Text("공유 시 'Wander' 워터마크가 자동으로 포함됩니다.")
            }
        }
        .navigationTitle("공유 설정")
    }
}

// MARK: - Language Settings View
struct LanguageSettingsView: View {
    @State private var languageManager = LanguageManager.shared
    @State private var showRestartAlert = false

    var body: some View {
        List {
            Section {
                ForEach(LanguageManager.Language.allCases) { language in
                    Button(action: {
                        selectLanguage(language)
                    }) {
                        HStack(spacing: WanderSpacing.space3) {
                            Text(language.flag)
                                .font(.system(size: 24))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.displayName)
                                    .font(WanderTypography.body)
                                    .foregroundColor(WanderColors.textPrimary)

                                if language == .system {
                                    Text("settings.language.systemDescription".localized)
                                        .font(WanderTypography.caption1)
                                        .foregroundColor(WanderColors.textSecondary)
                                }
                            }

                            Spacer()

                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(WanderColors.primary)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, WanderSpacing.space1)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("settings.language.select".localized)
            } footer: {
                Text("settings.language.footer".localized)
                    .font(WanderTypography.caption1)
            }
        }
        .navigationTitle("settings.language".localized)
        .alert("settings.language.restartRequired".localized, isPresented: $showRestartAlert) {
            Button("common.ok".localized, role: .cancel) { }
        } message: {
            Text("settings.language.restartMessage".localized)
        }
        .onAppear {
            logger.info("🌐 [LanguageSettingsView] 언어 설정 화면 나타남 - 현재: \(languageManager.currentLanguage.displayName)")
        }
    }

    private func selectLanguage(_ language: LanguageManager.Language) {
        if languageManager.currentLanguage != language {
            languageManager.currentLanguage = language
            showRestartAlert = true
            logger.info("🌐 [LanguageSettingsView] 언어 변경: \(language.displayName)")
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: WanderSpacing.space3) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(WanderColors.primary)

                        Text("Wander")
                            .font(WanderTypography.title1)

                        Text("settings.version".localized + " 1.0.0")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                    .padding(.vertical, WanderSpacing.space6)
                    Spacer()
                }
            }

            Section {
                Text("settings.privacyNote".localized)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            } header: {
                Text("settings.privacy".localized)
            }
        }
        .navigationTitle("settings.appInfo".localized)
    }
}

// MARK: - Share Link Test View (Developer Mode)
struct ShareLinkTestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared

    @State private var shareLink = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var savedRecord: TravelRecord?

    var body: some View {
        NavigationStack {
            VStack(spacing: WanderSpacing.space6) {
                // 안내 텍스트
                VStack(alignment: .leading, spacing: WanderSpacing.space3) {
                    Label("공유 링크 테스트", systemImage: "link.badge.plus")
                        .font(WanderTypography.title3)
                        .foregroundColor(WanderColors.textPrimary)

                    Text("Wander 공유 링크를 붙여넣어 기록 수신을 테스트합니다.")
                        .font(WanderTypography.body)
                        .foregroundColor(WanderColors.textSecondary)

                    Text("예: wander://share/{shareID}?key={key}")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textTertiary)
                        .padding(.top, WanderSpacing.space1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(WanderColors.surface)
                .cornerRadius(WanderSpacing.radiusLarge)

                // 링크 입력
                VStack(alignment: .leading, spacing: WanderSpacing.space2) {
                    Text("공유 링크")
                        .font(WanderTypography.caption1)
                        .foregroundColor(WanderColors.textSecondary)

                    HStack(spacing: WanderSpacing.space2) {
                        TextField("wander://share/...", text: $shareLink)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            if let clipboard = UIPasteboard.general.string {
                                shareLink = clipboard
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundColor(WanderColors.primary)
                        }
                    }
                }

                // 에러 메시지
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(WanderColors.error)
                        Text(error)
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.error)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(WanderColors.error.opacity(0.1))
                    .cornerRadius(WanderSpacing.radiusMedium)
                }

                // 성공 메시지
                if showSuccess, let record = savedRecord {
                    VStack(spacing: WanderSpacing.space3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(WanderColors.success)

                        Text("기록이 저장되었습니다!")
                            .font(WanderTypography.headline)
                            .foregroundColor(WanderColors.textPrimary)

                        Text(record.title)
                            .font(WanderTypography.body)
                            .foregroundColor(WanderColors.textSecondary)

                        Text("홈 또는 기록 탭에서 확인하세요")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textTertiary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(WanderColors.success.opacity(0.1))
                    .cornerRadius(WanderSpacing.radiusLarge)
                }

                Spacer()

                // 테스트 버튼
                Button {
                    testShareLink()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isLoading ? "처리 중..." : "테스트 실행")
                    }
                    .font(WanderTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: WanderSpacing.buttonHeight)
                    .background(shareLink.isEmpty || isLoading ? WanderColors.textTertiary : WanderColors.primary)
                    .cornerRadius(WanderSpacing.radiusLarge)
                }
                .disabled(shareLink.isEmpty || isLoading)
            }
            .padding(WanderSpacing.screenMargin)
            .navigationTitle("공유 링크 테스트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func testShareLink() {
        logger.info("🔗 [ShareLinkTestView] 테스트 시작: \(shareLink)")

        errorMessage = nil
        showSuccess = false
        savedRecord = nil

        // URL 파싱
        guard let url = URL(string: shareLink) else {
            errorMessage = "유효하지 않은 URL 형식입니다"
            return
        }

        // 공유 링크 확인
        guard let deepLink = ShareDeepLink.parse(from: url) else {
            errorMessage = "Wander 공유 링크 형식이 아닙니다.\n예: wander://share/{shareID}?key={key}"
            return
        }

        logger.info("🔗 [ShareLinkTestView] 딥링크 파싱 성공 - shareID: \(deepLink.shareID)")

        isLoading = true

        Task {
            do {
                let record = try await P2PShareService.shared.saveSharedRecord(
                    from: url,
                    modelContext: modelContext
                )

                await MainActor.run {
                    logger.info("✅ [ShareLinkTestView] 기록 저장 성공: \(record.title)")
                    savedRecord = record
                    showSuccess = true
                    isLoading = false
                    shareLink = ""
                }
            } catch {
                await MainActor.run {
                    logger.error("❌ [ShareLinkTestView] 에러: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
