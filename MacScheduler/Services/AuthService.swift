import Foundation
import Supabase
import SwiftUI

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isWaitingForGoogle = false
    @Published var errorMessage: String?

    private let client = SupabaseManager.shared.client
    private static let callbackURL = URL(string: "macscheduler://auth/callback")!

    /// CSRF state parameter for OAuth flows
    private var oauthState: String?

    private init() {}

    // MARK: - Session

    func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            currentUser = nil
            isAuthenticated = false
        }
    }

    // MARK: - Email/Password

    func signUp(email: String, password: String) async throws {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            currentUser = response.user
            isAuthenticated = response.session != nil
        } catch {
            errorMessage = Self.sanitizeAuthError(error)
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = Self.sanitizeAuthError(error)
            throw error
        }
    }

    // MARK: - Google SSO

    func signInWithGoogle() {
        isWaitingForGoogle = true
        errorMessage = nil

        // Generate CSRF state token
        let state = UUID().uuidString
        oauthState = state

        // Construct the Supabase OAuth URL for Google
        var components = URLComponents(string: "\(SupabaseManager.projectURL)/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: Self.callbackURL.absoluteString),
            URLQueryItem(name: "state", value: state)
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - OAuth Callback

    func handleAuthCallback(url: URL) async {
        defer {
            isWaitingForGoogle = false
            oauthState = nil
        }
        errorMessage = nil

        // Parse tokens from the URL fragment
        // Format: macscheduler://auth/callback#access_token=...&refresh_token=...&token_type=bearer&state=...
        guard let fragment = url.fragment else {
            errorMessage = "Authentication failed. Please try again."
            return
        }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let key = String(kv[0])
                let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                params[key] = value
            }
        }

        // Verify CSRF state if we initiated an OAuth flow
        if let expectedState = oauthState {
            guard params["state"] == expectedState else {
                errorMessage = "Authentication failed. Please try again."
                return
            }
        }

        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            errorMessage = "Authentication failed. Please try again."
            return
        }

        // Validate token format (JWT: 3 base64url-encoded segments separated by dots)
        guard Self.isValidJWTFormat(accessToken) else {
            errorMessage = "Authentication failed. Please try again."
            return
        }

        do {
            try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            errorMessage = "Authentication failed. Please try again."
        }
    }

    /// Basic JWT format validation: 3 non-empty base64url segments separated by dots.
    private static func isValidJWTFormat(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        let base64urlChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_="))
        return parts.allSatisfy { segment in
            !segment.isEmpty && segment.unicodeScalars.allSatisfy { base64urlChars.contains($0) }
        }
    }

    // MARK: - Sign Out & Reset

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Sign out locally even if server call fails
        }
        currentUser = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async throws {
        errorMessage = nil
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            errorMessage = Self.sanitizeAuthError(error)
            throw error
        }
    }

    /// Map raw auth errors to user-friendly messages that don't leak internal details.
    private static func sanitizeAuthError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") || message.contains("invalid_credentials") {
            return "Invalid email or password."
        }
        if message.contains("email not confirmed") {
            return "Please confirm your email address before signing in."
        }
        if message.contains("user already registered") || message.contains("already been registered") {
            return "An account with this email already exists."
        }
        if message.contains("password") && message.contains("weak") {
            return "Password is too weak. Please use a stronger password."
        }
        if message.contains("rate limit") || message.contains("too many requests") {
            return "Too many attempts. Please wait a moment and try again."
        }
        if message.contains("network") || message.contains("connection") || message.contains("offline") {
            return "Network error. Please check your internet connection."
        }
        if message.contains("timeout") {
            return "Request timed out. Please try again."
        }

        // Generic fallback — don't expose raw error details
        return "Authentication failed. Please try again."
    }
}
