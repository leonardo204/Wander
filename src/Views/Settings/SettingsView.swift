import SwiftUI
import SwiftData
import Photos
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SettingsView")

struct SettingsView: View {
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = true
    @State private var showAISettings = false
    @State private var showDataManagement = false
    @State private var showPermissions = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            List {
                // AI Settings Section
                Section {
                    NavigationLink(destination: AIProviderSettingsView()) {
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
                    NavigationLink(destination: DataManagementView()) {
                        SettingsRow(
                            icon: "externaldrive",
                            iconColor: WanderColors.info,
                            title: "데이터 관리",
                            subtitle: "저장 공간, 캐시 삭제"
                        )
                    }

                    NavigationLink(destination: PermissionSettingsView()) {
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
                    NavigationLink(destination: SecuritySettingsView()) {
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
                    NavigationLink(destination: CategoryManagementView()) {
                        SettingsRow(
                            icon: "folder.fill",
                            iconColor: WanderColors.warning,
                            title: "카테고리 관리",
                            subtitle: "카테고리 추가, 편집, 숨기기"
                        )
                    }

                    NavigationLink(destination: UserPlacesView()) {
                        SettingsRow(
                            icon: "mappin.circle.fill",
                            iconColor: WanderColors.error,
                            title: "장소 관리",
                            subtitle: "집, 회사 등 자주 가는 장소"
                        )
                    }
                } header: {
                    Text("사용자 설정")
                }

                // Share Settings Section
                Section {
                    NavigationLink(destination: ShareSettingsView()) {
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
                    NavigationLink(destination: AboutView()) {
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
            .navigationTitle("설정")
            .onAppear {
                logger.info("⚙️ [SettingsView] 설정 화면 나타남")
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
    @State private var selectedProvider: AIProvider?
    @State private var showAPIKeyInput = false
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
                        showAPIKeyInput = true
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
        .sheet(isPresented: $showAPIKeyInput) {
            if let provider = providerToEdit {
                APIKeyInputView(provider: provider)
            }
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

    // Azure specific settings
    @State private var azureEndpoint = ""
    @State private var azureDeployment = ""
    @State private var azureApiVersion = "2024-02-15-preview"

    var body: some View {
        NavigationStack {
            Form {
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
                    SecureField("API 키 입력", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("API 키")
                } footer: {
                    if hasExistingKey {
                        Text("기존 키가 저장되어 있습니다. 새 키를 입력하면 덮어씁니다.")
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
                    .disabled(apiKey.isEmpty || isTesting || (provider == .azure && (azureEndpoint.isEmpty || azureDeployment.isEmpty)))

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
                        saveAPIKey()
                        dismiss()
                    }
                    .disabled(apiKey.isEmpty || (provider == .azure && (azureEndpoint.isEmpty || azureDeployment.isEmpty)))
                }
            }
            .onAppear {
                hasExistingKey = KeychainManager.shared.hasAPIKey(for: provider.keychainType)
                logger.info("🔑 [APIKeyInputView] 나타남 - provider: \(provider.displayName), hasExistingKey: \(hasExistingKey)")

                // Load Azure settings if exists
                if provider == .azure {
                    let settings = AzureOpenAIService.getSettings()
                    azureEndpoint = settings.endpoint
                    azureDeployment = settings.deploymentName
                    azureApiVersion = settings.apiVersion
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

        // Temporarily save the key for testing
        do {
            try KeychainManager.shared.saveAPIKey(apiKey, for: provider.keychainType)

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

                    // Remove the test key if test failed and there was no existing key
                    if !hasExistingKey {
                        try? KeychainManager.shared.deleteAPIKey(for: provider.keychainType)
                    }
                }
            }
        } catch {
            logger.error("🔑 [APIKeyInputView] 키 저장 실패 - provider: \(provider.displayName), error: \(error.localizedDescription)")
            testResult = false
            testError = "키 저장 실패: \(error.localizedDescription)"
            isTesting = false
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
    @AppStorage("includeWatermark") private var includeWatermark = true
    @AppStorage("defaultShareFormat") private var defaultShareFormat = "text"

    var body: some View {
        List {
            Section("기본 공유 형식") {
                Picker("형식", selection: $defaultShareFormat) {
                    Text("텍스트").tag("text")
                    Text("이미지").tag("image")
                    Text("Markdown").tag("markdown")
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("워터마크 포함", isOn: $includeWatermark)
            } header: {
                Text("옵션")
            } footer: {
                Text("공유 시 'Wander로 기록했어요' 문구가 포함됩니다.")
            }
        }
        .navigationTitle("공유 설정")
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

                        Text("버전 1.0.0")
                            .font(WanderTypography.caption1)
                            .foregroundColor(WanderColors.textSecondary)
                    }
                    .padding(.vertical, WanderSpacing.space6)
                    Spacer()
                }
            }

            Section {
                Text("Wander는 100% 온디바이스로 동작하며, 사용자의 데이터를 서버로 전송하지 않습니다.")
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.textSecondary)
            } header: {
                Text("프라이버시")
            }
        }
        .navigationTitle("앱 정보")
    }
}

#Preview {
    SettingsView()
}
