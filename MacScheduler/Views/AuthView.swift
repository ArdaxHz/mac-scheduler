import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var licenseService: LicenseService
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var isSubmitting = false
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var resetSent = false

    private var emailError: String? {
        guard !email.isEmpty else { return nil }
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if email.range(of: pattern, options: .regularExpression) == nil {
            return "Enter a valid email address"
        }
        return nil
    }

    private var passwordError: String? {
        guard !password.isEmpty else { return nil }
        if password.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }

    private var confirmPasswordError: String? {
        guard isSignUp, !confirmPassword.isEmpty else { return nil }
        if confirmPassword != password {
            return "Passwords do not match"
        }
        return nil
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty &&
        emailError == nil && passwordError == nil &&
        (!isSignUp || (!confirmPassword.isEmpty && confirmPasswordError == nil))
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Mac Task Scheduler")
                    .font(.title)
                    .fontWeight(.bold)

                Text(isSignUp ? "Create your account" : "Sign in to your account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Google SSO
            Button {
                authService.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    if authService.isWaitingForGoogle {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "globe")
                    }
                    Text("Continue with Google")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            // Divider
            HStack {
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            }

            // Email/Password form
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                    if let error = emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                    if let error = passwordError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if isSignUp {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                        if let error = confirmPasswordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            // Submit
            Button {
                submit()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSignUp ? "Create Account" : "Sign In")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isFormValid || isSubmitting)

            // Toggle sign in / sign up
            HStack {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(.secondary)
                Button(isSignUp ? "Sign In" : "Sign Up") {
                    isSignUp.toggle()
                    confirmPassword = ""
                    errorText = ""
                }
                .buttonStyle(.link)
            }

            if !isSignUp {
                Button("Forgot Password?") {
                    resetEmail = email
                    showResetPassword = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(32)
        .frame(width: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
        .sheet(isPresented: $showResetPassword) {
            VStack(spacing: 16) {
                Text("Reset Password")
                    .font(.headline)

                TextField("Email", text: $resetEmail)
                    .textFieldStyle(.roundedBorder)

                if resetSent {
                    Label("Check your email for a reset link", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                }

                HStack {
                    Button("Cancel") {
                        showResetPassword = false
                        resetSent = false
                    }
                    .buttonStyle(.bordered)

                    Button("Send Reset Link") {
                        Task {
                            do {
                                try await authService.resetPassword(email: resetEmail)
                                resetSent = true
                            } catch {
                                errorText = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(resetEmail.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await licenseService.checkLicenseStatus() }
                dismiss()
            }
        }
        .onDisappear {
            authService.isWaitingForGoogle = false
            authService.errorMessage = nil
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
                if authService.isAuthenticated {
                    await licenseService.checkLicenseStatus()
                    dismiss()
                }
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
            isSubmitting = false
        }
    }
}
