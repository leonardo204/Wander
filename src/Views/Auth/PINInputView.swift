import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.zerolive.wander", category: "PINInputView")

/// PIN 입력 모드
enum PINInputMode {
    case verify       // PIN 확인
    case setup        // 새 PIN 설정
    case confirm      // PIN 확인 (설정 시)
    case change       // PIN 변경
}

/// PIN 입력 화면
struct PINInputView: View {
    let mode: PINInputMode
    let onSuccess: () -> Void
    let onCancel: (() -> Void)?

    @State private var enteredPIN = ""
    @State private var confirmPIN = ""
    @State private var isConfirmStep = false
    @State private var errorMessage: String?
    @State private var isShaking = false
    @State private var authManager = AuthenticationManager.shared

    @Environment(\.dismiss) private var dismiss

    init(mode: PINInputMode, onSuccess: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.mode = mode
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.top, WanderSpacing.space8)

            Spacer()

            // PIN Dots
            pinDotsSection
                .modifier(ShakeEffect(shakes: isShaking ? 2 : 0))

            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(WanderTypography.caption1)
                    .foregroundColor(WanderColors.error)
                    .padding(.top, WanderSpacing.space4)
            }

            // Lockout Timer
            if authManager.isLockedOut {
                lockoutSection
                    .padding(.top, WanderSpacing.space4)
            }

            Spacer()

            // Keypad
            keypadSection
                .padding(.bottom, WanderSpacing.space8)

            // Cancel Button
            if onCancel != nil || mode != .verify {
                Button("취소") {
                    onCancel?()
                    dismiss()
                }
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .padding(.bottom, WanderSpacing.space6)
            }
        }
        .background(WanderColors.background)
        .onAppear {
            // 생체인증 시도 (verify 모드이고 생체인증 활성화 시)
            if mode == .verify && authManager.isBiometricEnabled && authManager.canUseBiometric {
                attemptBiometricAuth()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            Image(systemName: headerIcon)
                .font(.system(size: 48))
                .foregroundColor(WanderColors.primary)

            Text(headerTitle)
                .font(WanderTypography.title2)
                .foregroundColor(WanderColors.textPrimary)

            Text(headerSubtitle)
                .font(WanderTypography.body)
                .foregroundColor(WanderColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, WanderSpacing.screenMargin)
    }

    private var headerIcon: String {
        switch mode {
        case .verify:
            return authManager.isLockedOut ? "lock.fill" : "lock.open.fill"
        case .setup, .confirm:
            return "lock.badge.plus"
        case .change:
            return "lock.rotation"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .verify:
            return "PIN 입력"
        case .setup:
            return "PIN 설정"
        case .confirm:
            return "PIN 확인"
        case .change:
            return isConfirmStep ? "새 PIN 확인" : "새 PIN 입력"
        }
    }

    private var headerSubtitle: String {
        if authManager.isLockedOut {
            return "잠시 후 다시 시도해 주세요"
        }

        switch mode {
        case .verify:
            return "4자리 PIN을 입력하세요"
        case .setup:
            return "새로운 4자리 PIN을 입력하세요"
        case .confirm:
            return "PIN을 한 번 더 입력하세요"
        case .change:
            return isConfirmStep ? "PIN을 한 번 더 입력하세요" : "새로운 4자리 PIN을 입력하세요"
        }
    }

    // MARK: - PIN Dots Section
    private var pinDotsSection: some View {
        HStack(spacing: WanderSpacing.space5) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < currentPIN.count ? WanderColors.primary : WanderColors.border)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private var currentPIN: String {
        if mode == .setup && isConfirmStep {
            return confirmPIN
        } else if mode == .change && isConfirmStep {
            return confirmPIN
        } else {
            return enteredPIN
        }
    }

    // MARK: - Lockout Section
    private var lockoutSection: some View {
        HStack(spacing: WanderSpacing.space2) {
            Image(systemName: "clock.fill")
                .foregroundColor(WanderColors.warning)

            Text("\(authManager.remainingLockoutSeconds)초 후 다시 시도")
                .font(WanderTypography.caption1)
                .foregroundColor(WanderColors.warning)
        }
        .padding(.horizontal, WanderSpacing.space4)
        .padding(.vertical, WanderSpacing.space2)
        .background(WanderColors.warningBackground)
        .cornerRadius(WanderSpacing.radiusMedium)
    }

    // MARK: - Keypad Section
    private var keypadSection: some View {
        VStack(spacing: WanderSpacing.space3) {
            ForEach(0..<3) { row in
                HStack(spacing: WanderSpacing.space3) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        KeypadButton(text: "\(number)") {
                            appendDigit("\(number)")
                        }
                        .disabled(authManager.isLockedOut)
                    }
                }
            }

            HStack(spacing: WanderSpacing.space3) {
                // Biometric Button (verify 모드에서만)
                if mode == .verify && authManager.isBiometricEnabled && authManager.canUseBiometric {
                    KeypadButton(systemImage: authManager.biometricIcon) {
                        attemptBiometricAuth()
                    }
                    .disabled(authManager.isLockedOut)
                } else {
                    Color.clear.frame(width: 72, height: 72)
                }

                // 0
                KeypadButton(text: "0") {
                    appendDigit("0")
                }
                .disabled(authManager.isLockedOut)

                // Delete
                KeypadButton(systemImage: "delete.left") {
                    deleteDigit()
                }
                .disabled(authManager.isLockedOut)
            }
        }
        .padding(.horizontal, WanderSpacing.screenMargin)
    }

    // MARK: - Actions
    private func appendDigit(_ digit: String) {
        errorMessage = nil

        if mode == .setup && isConfirmStep {
            guard confirmPIN.count < 4 else { return }
            confirmPIN += digit
            if confirmPIN.count == 4 {
                verifySetupPIN()
            }
        } else if mode == .change && isConfirmStep {
            guard confirmPIN.count < 4 else { return }
            confirmPIN += digit
            if confirmPIN.count == 4 {
                verifyChangePIN()
            }
        } else {
            guard enteredPIN.count < 4 else { return }
            enteredPIN += digit
            if enteredPIN.count == 4 {
                handlePINComplete()
            }
        }
    }

    private func deleteDigit() {
        if mode == .setup && isConfirmStep {
            if !confirmPIN.isEmpty {
                confirmPIN.removeLast()
            }
        } else if mode == .change && isConfirmStep {
            if !confirmPIN.isEmpty {
                confirmPIN.removeLast()
            }
        } else {
            if !enteredPIN.isEmpty {
                enteredPIN.removeLast()
            }
        }
        errorMessage = nil
    }

    private func handlePINComplete() {
        switch mode {
        case .verify:
            verifyPIN()
        case .setup:
            isConfirmStep = true
        case .confirm:
            verifyPIN()
        case .change:
            isConfirmStep = true
        }
    }

    private func verifyPIN() {
        if authManager.verifyPIN(enteredPIN) {
            logger.info("✅ [PINInputView] PIN 인증 성공")
            onSuccess()
        } else {
            logger.warning("❌ [PINInputView] PIN 인증 실패")
            showError("PIN이 일치하지 않습니다")
            enteredPIN = ""
        }
    }

    private func verifySetupPIN() {
        if enteredPIN == confirmPIN {
            if authManager.setPIN(enteredPIN) {
                logger.info("✅ [PINInputView] PIN 설정 성공")
                onSuccess()
            } else {
                showError("PIN 설정에 실패했습니다")
                resetPINEntry()
            }
        } else {
            showError("PIN이 일치하지 않습니다")
            resetPINEntry()
        }
    }

    private func verifyChangePIN() {
        if enteredPIN == confirmPIN {
            if authManager.setPIN(enteredPIN) {
                logger.info("✅ [PINInputView] PIN 변경 성공")
                onSuccess()
            } else {
                showError("PIN 변경에 실패했습니다")
                resetPINEntry()
            }
        } else {
            showError("PIN이 일치하지 않습니다")
            resetPINEntry()
        }
    }

    private func resetPINEntry() {
        enteredPIN = ""
        confirmPIN = ""
        isConfirmStep = false
    }

    private func showError(_ message: String) {
        errorMessage = message

        // Shake animation
        withAnimation(.default) {
            isShaking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShaking = false
        }
    }

    private func attemptBiometricAuth() {
        Task {
            let success = await authManager.authenticateWithBiometric()
            if success {
                await MainActor.run {
                    onSuccess()
                }
            }
        }
    }
}

// MARK: - Keypad Button
struct KeypadButton: View {
    let text: String?
    let systemImage: String?
    let action: () -> Void

    init(text: String, action: @escaping () -> Void) {
        self.text = text
        self.systemImage = nil
        self.action = action
    }

    init(systemImage: String, action: @escaping () -> Void) {
        self.text = nil
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(WanderColors.surface)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(WanderColors.border, lineWidth: 1)
                    )

                if let text = text {
                    Text(text)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(WanderColors.textPrimary)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 24))
                        .foregroundColor(WanderColors.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shake Effect
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(shakes * .pi * 4), y: 0))
    }
}

#Preview {
    PINInputView(mode: .verify, onSuccess: {})
}
