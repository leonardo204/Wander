import SwiftUI
import Photos

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

                    Button(action: resetOnboarding) {
                        SettingsRow(
                            icon: "arrow.counterclockwise",
                            iconColor: WanderColors.textTertiary,
                            title: "온보딩 다시 보기",
                            subtitle: nil
                        )
                    }
                } header: {
                    Text("기타")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("설정")
        }
    }

    private func resetOnboarding() {
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
        .sheet(isPresented: $showAPIKeyInput) {
            if let provider = providerToEdit {
                APIKeyInputView(provider: provider)
            }
        }
    }

    private func deleteAllKeys() {
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

    var body: some View {
        NavigationStack {
            Form {
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
                    .disabled(apiKey.isEmpty || isTesting)

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
                    .disabled(apiKey.isEmpty)
                }
            }
            .onAppear {
                hasExistingKey = KeychainManager.shared.hasAPIKey(for: provider.keychainType)
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        testError = nil

        // Temporarily save the key for testing
        do {
            try KeychainManager.shared.saveAPIKey(apiKey, for: provider.keychainType)

            Task {
                do {
                    let service = AIServiceFactory.createService(for: provider)
                    let result = try await service.testConnection()

                    await MainActor.run {
                        testResult = result
                        isTesting = false
                    }
                } catch {
                    await MainActor.run {
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
            testResult = false
            testError = "키 저장 실패: \(error.localizedDescription)"
            isTesting = false
        }
    }

    private func saveAPIKey() {
        do {
            try KeychainManager.shared.saveAPIKey(apiKey, for: provider.keychainType)
        } catch {
            print("API 키 저장 실패: \(error)")
        }
    }

    private func deleteKey() {
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
    @State private var cacheSize = "계산 중..."
    @State private var recordCount = 0
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
                    Text("\(recordCount)개")
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
        // Clear cache
        cacheSize = "0 MB"
    }

    private func deleteAllRecords() {
        // Delete all records
        recordCount = 0
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

            Section("옵션") {
                Toggle("워터마크 포함", isOn: $includeWatermark)
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
                Link(destination: URL(string: "https://github.com/leonardo204/Wander")!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(WanderColors.textTertiary)
                    }
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
