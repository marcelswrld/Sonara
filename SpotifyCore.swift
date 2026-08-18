import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import Security

// =====================================================================
// SpotifyCore — PKCE auth for Sonara (standalone).
//
// STANDALONE SPOTIFY APP: uses Sonara's own Spotify registration
// (client ID below), NOT Musiclips'. Redirect URI "sonara://callback"
// must be whitelisted in Sonara's Spotify dashboard.
//
// HEADS-UP ON NEW-APP ENDPOINT LIMITS: Spotify restricted some endpoints
// (notably /recommendations and 30s preview_url) for apps created after
// Nov 2024. Sonara's app is new, so if recommendations or previews come
// back empty in testing, that's why — we'll switch Discover to a
// supported source (e.g. new releases / search / user top tracks).
//
// WHY NO CLIENT SECRET: the old app embedded the secret in the binary
// (Constants.swift) — anyone can extract it. PKCE removes the need for
// a secret entirely. SECURITY ACTION ITEM: the old secret should be
// rotated in the Spotify dashboard since it shipped inside prior
// builds. Rotating it does NOT break this app (PKCE never uses it).
// =====================================================================

enum SpotifyConfig {
    static let clientID = "9f8cd743c2354f5d804637d69f65d370" // Sonara's own Spotify app (standalone)
    // NOTE: this exact string must be registered in the Spotify Developer
    // Dashboard → this app → Settings → Redirect URIs. A bare "scheme://"
    // is often rejected by Spotify and by ASWebAuthenticationSession, so we
    // use a path component. Whatever value is used here MUST match the
    // dashboard entry character-for-character.
    static let redirectURI = "sonara://callback"
    static let callbackScheme = "sonara"
    static let authBase = "https://accounts.spotify.com"
    static let apiBase = "https://api.spotify.com/v1"
    static let scopes = [
        "user-library-read", "user-library-modify",
        "user-top-read",
        "user-read-recently-played",
        "user-follow-modify", "user-follow-read",
        "playlist-read-private", "playlist-modify-public",
        "playlist-modify-private", "playlist-read-collaborative",
        "user-read-private"
    ].joined(separator: " ")
}

// MARK: - Minimal Keychain (tokens don't belong in UserDefaults)

enum Keychain {
    @discardableResult
    static func set(_ value: String, key: String) -> Bool {
        let data = Data(value.utf8)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func delete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - Auth (PKCE)

@MainActor
final class SpotifyAuth: NSObject, ObservableObject,
                         ASWebAuthenticationPresentationContextProviding {

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var lastError: String?

    private var codeVerifier = ""
    private static let kAccess = "sp.access", kRefresh = "sp.refresh", kExpiry = "sp.expiry"

    override init() {
        isSignedIn = Keychain.get(Self.kRefresh) != nil
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    // Same ASWebAuthenticationSession pattern as Musiclips' AuthManager.
    func signIn() {
        codeVerifier = Self.randomVerifier()
        let challenge = Self.challenge(for: codeVerifier)
        var c = URLComponents(string: SpotifyConfig.authBase + "/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: SpotifyConfig.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            .init(name: "scope", value: SpotifyConfig.scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge)
        ]
        let session = ASWebAuthenticationSession(
            url: c.url!,
            callbackURLScheme: SpotifyConfig.callbackScheme) { [weak self] callback, error in
                guard let self else { return }
                if let callback,
                   let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                       .queryItems?.first(where: { $0.name == "code" })?.value {
                    Task { await self.exchange(code: code) }
                } else if let error {
                    Task { @MainActor in self.lastError = error.localizedDescription }
                }
            }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        session.start()
    }

    func signOut() {
        [Self.kAccess, Self.kRefresh, Self.kExpiry].forEach(Keychain.delete)
        isSignedIn = false
    }

    /// Valid access token, refreshing if needed. nil = signed out.
    func validToken() async -> String? {
        if let exp = Keychain.get(Self.kExpiry), let t = TimeInterval(exp),
           Date().timeIntervalSince1970 < t - 60,
           let access = Keychain.get(Self.kAccess) {
            return access
        }
        return await refresh()
    }

    // MARK: internals

    private func exchange(code: String) async {
        await token(body: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": codeVerifier
        ])
    }

    private func refresh() async -> String? {
        guard let r = Keychain.get(Self.kRefresh) else { return nil }
        return await token(body: [
            "grant_type": "refresh_token",
            "refresh_token": r,
            "client_id": SpotifyConfig.clientID
        ])
    }

    @discardableResult
    private func token(body: [String: String]) async -> String? {
        var req = URLRequest(url: URL(string: SpotifyConfig.authBase + "/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $1)" }
            .joined(separator: "&").data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            struct TokenResponse: Decodable {
                let access_token: String
                let expires_in: Int
                let refresh_token: String?
            }
            let t = try JSONDecoder().decode(TokenResponse.self, from: data)
            Keychain.set(t.access_token, key: Self.kAccess)
            if let r = t.refresh_token { Keychain.set(r, key: Self.kRefresh) } // PKCE rotates it
            Keychain.set(String(Date().timeIntervalSince1970 + Double(t.expires_in)),
                         key: Self.kExpiry)
            isSignedIn = true
            lastError = nil
            return t.access_token
        } catch {
            lastError = "Sign-in failed: \(error.localizedDescription)"
            return nil
        }
    }

    private static func randomVerifier() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }
    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
