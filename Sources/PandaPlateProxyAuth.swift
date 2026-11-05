import AuthenticationServices
import CryptoKit
import Foundation
import Security
import SwiftUI
import UIKit

struct PandaPlateProxySession: Codable, Equatable {
    let sessionToken: String
    let expiresAt: Int

    func isValid(at date: Date = Date()) -> Bool {
        !sessionToken.isEmpty && expiresAt > Int(date.timeIntervalSince1970)
    }
}

enum PandaPlateProxyIdentityProvider: String, Codable {
    case apple
}

struct PandaPlateProxyIdentity {
    let provider: PandaPlateProxyIdentityProvider
    let userID: String
    let email: String?
}

enum PandaPlateProxyConfiguration {
    static let defaultBaseURL = "https://pandaplate-ai-proxy.charliengyt.workers.dev"
    static let baseURLDefaultsKey = "pandaplate.scanBaseURL"
    static let baseURLInfoKey = "PandaPlateProxyBaseURL"

    static func baseURL(
        defaults: UserDefaults = .standard,
        infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> URL {
        let override = defaults.string(forKey: baseURLDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let configured = infoDictionary[baseURLInfoKey] as? String
        let value = (override?.isEmpty == false ? override : configured)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = value?.isEmpty == false ? value! : defaultBaseURL
        guard let url = URL(string: rawValue), isAllowedBaseURL(url) else {
            throw PandaPlateProxyError.invalidBaseURL
        }
        return url
    }

    static func isAllowedBaseURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return false
        }
        if scheme == "https" { return true }
        guard scheme == "http" else { return false }
        return ["127.0.0.1", "localhost", "::1"].contains(host)
    }


    static func appleRequestNonce(for rawNonce: String) -> String {
        SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

enum PandaPlateProxyError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(Int)
    case serverError(String)
    case network(String)
    case missingAppleIdentityToken
    case missingSession
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The scan server address must use HTTPS, except for the local loopback server."
        case .invalidResponse:
            return "The scan server returned an unreadable response."
        case .httpStatus(let status):
            return "The scan server returned an unexpected response (\(status))."
        case .serverError(let code):
            return Self.message(forServerCode: code)
        case .network:
            return "Couldn’t reach the PandaPlate scan server. You can still log meals manually."
        case .missingAppleIdentityToken:
            return "Apple didn’t return an identity token. Try signing in again."
        case .missingSession:
            return "Your scan session is missing or expired. Sign in again to scan; manual logging is still available."
        case .keychain:
            return "Secure session storage isn’t available right now. You can still log meals manually."
        }
    }

    private static func message(forServerCode code: String) -> String {
        switch code {
        case "unauthorized", "invalid_identity_token", "nonce_expired_or_reused", "invalid_nonce":
            return "Sign-in could not be verified. Please try again. Manual logging is still available."
        case "identity_provider_not_configured":
            return "The scan server is missing an identity-provider setting. You can still log meals manually."
        case "session_signing_not_configured", "session_issue_failed":
            return "The scan server isn’t ready to create a secure session. You can still log meals manually."
        case "too_many_auth_requests":
            return "There have been too many sign-in attempts. Wait a moment and try again."
        default:
            return "Proxy sign-in couldn’t finish (\(code)). Manual logging is still available."
        }
    }
}

protocol PandaPlateProxySessionStore: AnyObject {
    func load() throws -> PandaPlateProxySession?
    func save(_ session: PandaPlateProxySession) throws
    func clear() throws
}

final class KeychainPandaPlateProxySessionStore: PandaPlateProxySessionStore {
    private let service: String
    private let account = "app-session"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.charlie.pandaplate") {
        self.service = service
    }

    func load() throws -> PandaPlateProxySession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PandaPlateProxyError.keychain(status)
        }
        guard let session = try? JSONDecoder().decode(PandaPlateProxySession.self, from: data) else {
            try? clear()
            return nil
        }
        return session
    }

    func save(_ session: PandaPlateProxySession) throws {
        let data = try JSONEncoder().encode(session)
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let updateStatus = SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw PandaPlateProxyError.keychain(updateStatus)
        }
        var add = key
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw PandaPlateProxyError.keychain(addStatus) }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PandaPlateProxyError.keychain(status)
        }
    }
}

struct PandaPlateProxyAuthClient {
    let baseURL: URL
    var session: URLSession = .shared

    func fetchNonce(for provider: PandaPlateProxyIdentityProvider) async throws -> String {
        let response: ProxyNonceResponse = try await send(
            path: "v1/auth/nonce",
            body: NonceRequest(provider: provider),
            bearerToken: nil
        )
        guard (32...128).contains(response.nonce.count) else {
            throw PandaPlateProxyError.invalidResponse
        }
        return response.nonce
    }

    func exchangeAppleIdentityToken(_ identityToken: String, rawNonce: String) async throws -> PandaPlateProxySession {
        guard !identityToken.isEmpty else { throw PandaPlateProxyError.missingAppleIdentityToken }
        return try await send(
            path: "v1/auth/session",
            body: SessionExchangeBody(provider: .apple, nonce: rawNonce),
            bearerToken: identityToken
        )
    }


    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body,
        bearerToken: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PandaPlateProxyError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw PandaPlateProxyError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ProxyErrorResponse.self, from: data),
               let code = payload.error {
                throw PandaPlateProxyError.serverError(code)
            }
            throw PandaPlateProxyError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw PandaPlateProxyError.invalidResponse
        }
    }
}

final class PandaPlateProxyAuthService {
    static let shared = PandaPlateProxyAuthService(store: KeychainPandaPlateProxySessionStore())

    private let store: PandaPlateProxySessionStore

    init(store: PandaPlateProxySessionStore) {
        self.store = store
    }

    func validSession(at date: Date = Date()) throws -> PandaPlateProxySession? {
        guard let session = try store.load() else { return nil }
        guard session.isValid(at: date) else {
            try store.clear()
            return nil
        }
        return session
    }

    func save(_ session: PandaPlateProxySession) throws {
        guard session.isValid() else { throw PandaPlateProxyError.missingSession }
        try store.save(session)
    }

    func clearSession() {
        try? store.clear()
    }

    func fetchNonce(for provider: PandaPlateProxyIdentityProvider) async throws -> String {
        try await client().fetchNonce(for: provider)
    }

    func authenticateApple(identityToken: String, rawNonce: String) async throws {
        let session = try await client().exchangeAppleIdentityToken(identityToken, rawNonce: rawNonce)
        try save(session)
    }


    private func client() throws -> PandaPlateProxyAuthClient {
        PandaPlateProxyAuthClient(baseURL: try PandaPlateProxyConfiguration.baseURL())
    }
}

@MainActor
final class PandaPlateProxySignInCoordinator: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published private(set) var busyProvider: PandaPlateProxyIdentityProvider?
    @Published private(set) var errorMessage: String?

    private let authService: PandaPlateProxyAuthService
    private let onAuthenticated: (PandaPlateProxyIdentity) -> Void
    private var appleNonce: String?
    private var appleController: ASAuthorizationController?
    private var presentationWindow: UIWindow?

    init(
        authService: PandaPlateProxyAuthService = .shared,
        onAuthenticated: @escaping (PandaPlateProxyIdentity) -> Void
    ) {
        self.authService = authService
        self.onAuthenticated = onAuthenticated
    }

    func signInWithApple() {
        guard busyProvider == nil else { return }
        errorMessage = nil
        busyProvider = .apple
        Task {
            do {
                let rawNonce = try await authService.fetchNonce(for: .apple)
                guard let window = Self.activeWindow() else {
                    throw PandaPlateProxyError.invalidResponse
                }
                appleNonce = rawNonce
                presentationWindow = window
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.requestedScopes = [.fullName, .email]
                request.nonce = PandaPlateProxyConfiguration.appleRequestNonce(for: rawNonce)
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                appleController = controller
                controller.performRequests()
            } catch {
                finish(with: error)
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let rawNonce = appleNonce,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            Task { @MainActor in self.finish(with: PandaPlateProxyError.missingAppleIdentityToken) }
            return
        }
        appleNonce = nil
        Task { @MainActor in
            do {
                try await authService.authenticateApple(identityToken: identityToken, rawNonce: rawNonce)
                busyProvider = nil
                onAuthenticated(PandaPlateProxyIdentity(
                    provider: .apple,
                    userID: credential.user,
                    email: credential.email
                ))
            } catch {
                finish(with: error)
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let nsError = error as NSError
        Task { @MainActor in
            appleNonce = nil
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                busyProvider = nil
                return
            }
            finish(with: error)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationWindow ?? UIWindow(frame: .zero)
    }

    private func finish(with error: Error) {
        busyProvider = nil
        appleNonce = nil
        appleController = nil
        presentationWindow = nil
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? "Sign-in couldn’t finish. Try again or use manual logging."
    }

    private static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return active?.windows.first(where: \.isKeyWindow) ?? active?.windows.first
    }

    #if DEBUG
    /// Local Simulator / Debug bypass — no Apple ID, no proxy session token.
    /// Unlocks the same onboarding completion path as SIWA via `onAuthenticated`.
    /// Must stay inside `#if DEBUG` so Release / Archive binaries strip UI + entry.
    func continueAsDeveloper() {
        guard busyProvider == nil else { return }
        errorMessage = nil
        onAuthenticated(
            PandaPlateProxyIdentity(
                provider: .apple,
                userID: PandaPlateDebugDeveloperSignIn.userID,
                email: PandaPlateDebugDeveloperSignIn.email
            )
        )
    }
    #endif
}

struct PandaPlateProxySignInButtons: View {
    @StateObject private var coordinator: PandaPlateProxySignInCoordinator

    init(onAuthenticated: @escaping (PandaPlateProxyIdentity) -> Void) {
        _coordinator = StateObject(wrappedValue: PandaPlateProxySignInCoordinator(onAuthenticated: onAuthenticated))
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: coordinator.signInWithApple) {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    if coordinator.busyProvider == .apple {
                        ProgressView().tint(.white).accessibilityHidden(true)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 19, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(coordinator.busyProvider == .apple ? "Connecting to Apple…" : "Sign in with Apple")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.black, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(coordinator.busyProvider != nil)
            .accessibilityLabel(coordinator.busyProvider == .apple ? "Connecting to Apple" : "Sign in with Apple")

            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("proxySignInError")
            }

            #if DEBUG
            // Compile-time Debug-only. Release / App Store archive cannot show this control.
            Button(action: coordinator.continueAsDeveloper) {
                Text("Continue as Developer")
                    .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(PPColor.peach.opacity(0.55), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(PPColor.coralInk.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(coordinator.busyProvider != nil)
            .accessibilityLabel("Continue as Developer")
            .accessibilityHint("Debug builds only. Skips Sign in with Apple on Simulator.")
            .accessibilityIdentifier("proxySignInContinueAsDeveloper")

            Text("Debug only — no Apple ID. Local session for Simulator; not in Release.")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("proxySignInDeveloperHint")
            #endif
        }
    }
}

private struct ProxyNonceResponse: Decodable {
    let nonce: String
    let expiresInSeconds: Int
}

private struct SessionExchangeBody: Encodable {
    let provider: PandaPlateProxyIdentityProvider
    let nonce: String?
}

private struct NonceRequest: Encodable {
    let provider: PandaPlateProxyIdentityProvider
}

private struct ProxyErrorResponse: Decodable {
    let error: String?
}

#if DEBUG
/// Stable local identity used by Debug “Continue as Developer”.
/// Entire type is `#if DEBUG` so Release / Archive cannot reference or embed it.
enum PandaPlateDebugDeveloperSignIn {
    static let userID = "pandaplate.debug.developer"
    static let email = "developer@localhost"
}
#endif

