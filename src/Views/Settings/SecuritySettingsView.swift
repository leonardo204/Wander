import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "SecuritySettingsView")

/// 보안 설정 화면
struct SecuritySettingsView: View {
    @State private var authManager = AuthenticationManager.shared
    @State private var showPINSetup = false
    @State private var showPINChange = false
    @State private var showPINVerify = false
    @State private var showRemovePINConfirm = false
    @State private var pendingBiometricToggle = false

    var body: some View {
        List {
            // PIN Section
            Section {
                if authManager.isPINSet {
                    // PIN 변경
                    Button(action: { showPINChange = true }) {
                        HStack {
                            Label("PIN 변경", systemImage: "lock.rotation")
                            Spacer()
                        }
                    }
                    .foregroundColor(WanderColors.textPrimary)

                    // PIN 삭제
                    Button(action: { showRemovePINConfirm = true }) {
                        Label("PIN 삭제", systemImage: "lock.slash")
                    }
                    .foregroundColor(WanderColors.error)
                } else {
                    // PIN 설정
                    Button(action: { showPINSetup = true }) {
                        HStack {
                            Label("PIN 설정", systemImage: "lock.badge.plus")
                            Spacer()
                            Text("설정되지 않음")
                                .font(WanderTypography.caption1)
                                .foregroundColor(WanderColors.textTertiary)
                        }
                    }
                    .foregroundColor(WanderColors.textPrimary)
                }
            } header: {
                Text("PIN")
            } footer: {
                Text("PIN을 설정하면 숨긴 기록에 접근할 때 인증이 필요합니다.")
            }

            // Biometric Section
            if authManager.canUseBiometric && authManager.isPINSet {
                Section {
                    Toggle(isOn: Binding(
                        get: { authManager.isBiometricEnabled },
                        set: { newValue in
                            if newValue {
                                // 생체인증 활성화 시 PIN 확인
                                pendingBiometricToggle = true
                                showPINVerify = true
                            } else {
                                authManager.isBiometricEnabled = false
                            }
                        }
                    )) {
                        Label(authManager.biometricName, systemImage: authManager.biometricIcon)
                    }
                    .tint(WanderColors.primary)
                } header: {
                    Text("생체인증")
                } footer: {
                    Text("\(authManager.biometricName)을 사용하여 빠르게 인증할 수 있습니다. 생체인증 실패 시 PIN으로 인증합니다.")
                }
            }

            // Info Section
            Section {
                HStack {
                    Label("인증 유지 시간", systemImage: "clock")
                    Spacer()
                    Text("5분")
                        .foregroundColor(WanderColors.textSecondary)
                }

                HStack {
                    Label("잠금 조건", systemImage: "lock.fill")
                    Spacer()
                    Text("3회 실패 시 30초")
                        .foregroundColor(WanderColors.textSecondary)
                }
            } header: {
                Text("정보")
            }
        }
        .navigationTitle("보안")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPINSetup) {
            NavigationStack {
                PINInputView(mode: .setup, onSuccess: {
                    showPINSetup = false
                    logger.info("✅ [SecuritySettings] PIN 설정 완료")
                }, onCancel: {
                    showPINSetup = false
                })
                .navigationTitle("PIN 설정")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showPINChange) {
            NavigationStack {
                PINInputView(mode: .change, onSuccess: {
                    showPINChange = false
                    logger.info("✅ [SecuritySettings] PIN 변경 완료")
                }, onCancel: {
                    showPINChange = false
                })
                .navigationTitle("PIN 변경")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showPINVerify) {
            NavigationStack {
                PINInputView(mode: .verify, onSuccess: {
                    showPINVerify = false
                    if pendingBiometricToggle {
                        authManager.isBiometricEnabled = true
                        pendingBiometricToggle = false
                        logger.info("✅ [SecuritySettings] 생체인증 활성화")
                    }
                }, onCancel: {
                    showPINVerify = false
                    pendingBiometricToggle = false
                })
                .navigationTitle("PIN 확인")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .confirmationDialog(
            "PIN을 삭제하시겠습니까?",
            isPresented: $showRemovePINConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                authManager.removePIN()
                logger.info("🗑️ [SecuritySettings] PIN 삭제됨")
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("PIN을 삭제하면 생체인증도 함께 비활성화됩니다.")
        }
    }
}

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
