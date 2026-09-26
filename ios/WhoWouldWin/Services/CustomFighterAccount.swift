import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import StoreKit
import UIKit

/// Identity is separate from a revocable session and creation entitlement.
/// Expiration never hides downloaded artwork; explicit sign-out does.
@MainActor
final class CustomFighterAccount: NSObject, ObservableObject {
    static let shared = CustomFighterAccount()
    @Published private(set) var accountID: String?
    @Published private(set) var sessionToken: String?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    var isSignedIn: Bool { accountID != nil && sessionToken != nil }

    struct SavedSession: Codable, Equatable {
        let accountID: String
        let sessionToken: String?
        let expiresAt: String?
        let appleUserID: String?
    }
    private struct SessionResponse: Decodable { let accountID: String; let sessionToken: String; let expiresAt: String }
    private struct Challenge: Decodable { let challengeID: String; let nonce: String }
    private struct AppleIdentity { let token: String; let userID: String }
    private var savedSession: SavedSession?
    private var pendingAuthorization: CheckedContinuation<AppleIdentity, Error>?
    private var expectedState: String?
    private var authorizationController: ASAuthorizationController?
    private var operationEpoch: UInt64 = 0
    private var observers: [NSObjectProtocol] = []
    private var credentialCheckInProgress = false
    private let redirectGuard = CustomFighterAuthRedirectGuard()
    private lazy var network: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil; configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
    }()

    private override init() {
        super.init()
        guard AppConfig.externalServicesEnabled else { return }
        if let data = readSessionData(), let restored = Self.restoreSession(from: data) {
            savedSession = restored; accountID = restored.accountID; sessionToken = restored.sessionToken
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard AppConfig.externalServicesEnabled else { return }
                await self?.revokeCredential()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.checkCredentialState() } })
        checkCredentialState()
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    /// Pure restoration also covers legacy Keychain records without invoking
    /// Apple, StoreKit, networking or real application storage in unit tests.
    nonisolated static func restoreSession(from data: Data, now: Date = Date()) -> SavedSession? {
        guard data.count <= 16_384, let value = try? JSONDecoder().decode(SavedSession.self, from: data),
              let owner = UUID(uuidString: value.accountID)?.uuidString.lowercased() else { return nil }
        let token: String?
        if let candidate = value.sessionToken, validToken(candidate), let expiry = value.expiresAt.flatMap(date), expiry > now {
            token = candidate
        } else { token = nil }
        let appleUserID = value.appleUserID.flatMap { user in
            !user.isEmpty && user.utf8.count <= 512 && user.rangeOfCharacter(from: .controlCharacters) == nil ? user : nil
        }
        return SavedSession(accountID: owner, sessionToken: token, expiresAt: token == nil ? nil : value.expiresAt, appleUserID: appleUserID)
    }

    func beginSignIn() async {
        guard !isWorking, AppConfig.externalServicesEnabled else { return }
        operationEpoch &+= 1; let epoch = operationEpoch
        isWorking = true; errorMessage = nil
        defer {
            if epoch == operationEpoch { isWorking = false; expectedState = nil; authorizationController = nil }
        }
        do {
            let challenge: Challenge = try await send("challenge", method: "POST", body: [:])
            try requireCurrent(epoch)
            guard UUID(uuidString: challenge.challengeID) != nil, Self.validToken(challenge.nonce) else { throw AccountError.invalidResponse }
            expectedState = challenge.challengeID
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            request.state = challenge.challengeID
            request.nonce = SHA256.hash(data: Data(challenge.nonce.utf8)).map { String(format: "%02x", $0) }.joined()
            let identity: AppleIdentity = try await withCheckedThrowingContinuation { continuation in
                pendingAuthorization = continuation
                let controller = ASAuthorizationController(authorizationRequests: [request])
                authorizationController = controller
                controller.delegate = self; controller.presentationContextProvider = self
                controller.performRequests()
            }
            try requireCurrent(epoch)
            let response: SessionResponse = try await send("apple", method: "POST",
                body: ["challengeID": challenge.challengeID, "identityToken": identity.token])
            try requireCurrent(epoch)
            guard let owner = UUID(uuidString: response.accountID)?.uuidString.lowercased(), Self.validToken(response.sessionToken),
                  let expires = Self.date(response.expiresAt), expires > Date() else { throw AccountError.invalidResponse }
            let session = SavedSession(accountID: owner, sessionToken: response.sessionToken,
                expiresAt: response.expiresAt, appleUserID: identity.userID)
            try saveSession(session)
            savedSession = session; sessionToken = session.sessionToken; accountID = session.accountID
        } catch {
            guard epoch == operationEpoch else { return }
            if !(error is CancellationError), (error as? ASAuthorizationError)?.code != .canceled { errorMessage = error.localizedDescription }
        }
    }

    func signOut() async {
        let token = sessionToken
        // Invalidate in-flight work before waiting for a best-effort HTTP request.
        clearSession(hideOwner: true); errorMessage = nil
        if let token { try? await sendEmpty("signout", method: "POST", bearer: token) }
    }

    /// Parent-gated device reset. Remote deletion is a separate explicit flow.
    func eraseLocalSession() { clearSession(hideOwner: true); errorMessage = nil }

    #if DEBUG
    /// Synthetic UI state only. The Release binary cannot manufacture a session,
    /// and both runtime and isolated-bundle guards must hold in test builds.
    func prepareUITestSession(accountID: String) {
        guard AppConfig.isUITesting, AppConfig.isIsolatedTestBuild,
              let owner = UUID(uuidString: accountID)?.uuidString.lowercased() else { return }
        operationEpoch &+= 1
        savedSession = nil
        sessionToken = String(repeating: "u", count: 43)
        self.accountID = owner
        errorMessage = nil
    }
    #endif

    func deleteAccount() async {
        guard !isWorking, let token = sessionToken, accountID != nil else { return }
        operationEpoch &+= 1; let epoch = operationEpoch
        isWorking = true; errorMessage = nil
        defer { if epoch == operationEpoch { isWorking = false } }
        do {
            try await sendEmpty("account", method: "DELETE", bearer: token)
            try requireCurrent(epoch)
            let requestsRemoved = CustomFighterService.shared.clearLocalState()
            var artworkRemoved = true
            do { try CustomFighterLibraryStore.shared.eraseAllLocalData() }
            catch { artworkRemoved = false }
            // The server account is already gone. Clear its credentials even if
            // a local filesystem failure requires a separate device-data retry.
            clearSession(hideOwner: true)
            if !requestsRemoved || !artworkRemoved {
                errorMessage = "Your online library was deleted, but this device could not remove all saved files. Use the erase-data control in the Grown-Up Zone to retry local cleanup."
            }
        } catch {
            if epoch == operationEpoch { errorMessage = error.localizedDescription }
        }
    }

    /// Expired/rejected tokens require reauthentication, not loss of the saved
    /// offline owner. Confirmed Apple credential revocation instead signs out.
    func invalidateSession() {
        clearSession(hideOwner: false)
        if accountID != nil { errorMessage = AccountError.signInRequired.localizedDescription }
    }

    func refreshSubscriptionJWS() async throws -> String? {
        guard AppConfig.externalServicesEnabled else { return nil }
        await StoreKitManager.shared.refreshEntitlements()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  [StoreKitManager.premiumMonthlyID, StoreKitManager.premiumAnnualID].contains(transaction.productID),
                  transaction.revocationDate == nil,
                  let expiration = transaction.expirationDate, expiration > Date() else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    private func clearSession(hideOwner: Bool) {
        operationEpoch &+= 1
        let pending = pendingAuthorization; pendingAuthorization = nil
        pending?.resume(throwing: CancellationError())
        expectedState = nil; authorizationController = nil; isWorking = false
        sessionToken = nil
        if hideOwner {
            SecItemDelete(keychainQuery() as CFDictionary)
            savedSession = nil; accountID = nil
            try? CustomFighterLibraryStore.shared.setOwner(ownerID: nil)
        } else if let previous = savedSession {
            let offline = SavedSession(accountID: previous.accountID, sessionToken: nil, expiresAt: nil, appleUserID: previous.appleUserID)
            savedSession = offline
            // If secure storage cannot be rewritten, do not restore a known bad token.
            do { try saveSession(offline) } catch { SecItemDelete(keychainQuery() as CFDictionary) }
        }
    }

    private func requireCurrent(_ epoch: UInt64) throws {
        guard epoch == operationEpoch else { throw CancellationError() }
    }
    private func revokeCredential() async {
        guard AppConfig.externalServicesEnabled else { return }
        let token = sessionToken
        clearSession(hideOwner: true)
        let epoch = operationEpoch
        if let token { try? await sendEmpty("signout", method: "POST", bearer: token) }
        if epoch == operationEpoch { errorMessage = "Your Apple sign-in was disconnected. Sign in again to open this library." }
    }
    private func checkCredentialState() {
        guard AppConfig.externalServicesEnabled, !credentialCheckInProgress, !isWorking,
              sessionToken != nil, let user = savedSession?.appleUserID else { return }
        credentialCheckInProgress = true; let epoch = operationEpoch
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { [weak self] state, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.credentialCheckInProgress = false
                guard self.operationEpoch == epoch, error == nil else { return }
                switch state {
                case .revoked, .notFound, .transferred: await self.revokeCredential()
                case .authorized: break
                @unknown default: await self.revokeCredential()
                }
            }
        }
    }

    private func send<T: Decodable>(_ path: String, method: String, body: [String: String]?) async throws -> T {
        let data = try await sendData(path, method: method, body: body, bearer: nil)
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func sendEmpty(_ path: String, method: String, bearer: String) async throws {
        _ = try await sendData(path, method: method, body: nil, bearer: bearer)
    }
    /// Every account operation belongs to the same private library service as
    /// artwork requests. The battle API can be a separate deployment.
    struct BackendConfiguration {
        let battleBaseURL: String
        let customFighterBaseURL: String

        nonisolated static var current: BackendConfiguration {
            BackendConfiguration(battleBaseURL: AppConfig.backendBaseURL,
                                 customFighterBaseURL: AppConfig.customFighterBaseURL)
        }
    }

    nonisolated static func authenticationURL(for path: String, configuration: BackendConfiguration = .current) -> URL? {
        guard ["challenge", "apple", "signout", "account"].contains(path),
              let base = URL(string: configuration.customFighterBaseURL), base.scheme == "https", base.host?.isEmpty == false,
              base.user == nil, base.password == nil, base.query == nil, base.fragment == nil else { return nil }
        return base.appendingPathComponent("api/custom-fighters/auth").appendingPathComponent(path)
    }

    /// A session is valid only for the library deployment that issued it. Do
    /// not import credentials from the old battle-service Keychain namespace.
    nonisolated static func sessionKeychainQuery(
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.whowouldin.WhoWouldWin",
        configuration: BackendConfiguration = .current
    ) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: bundleIdentifier + ".fighter-account",
         kSecAttrAccount as String: configuration.customFighterBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
    }

    private func sendData(_ path: String, method: String, body: [String: String]?, bearer: String?) async throws -> Data {
        guard AppConfig.externalServicesEnabled, let url = Self.authenticationURL(for: path) else {
            throw AccountError.unavailable
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer { request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (stream, response) = try await network.bytes(for: request)
        guard let http = response as? HTTPURLResponse, response.url == url,
              response.expectedContentLength <= 65536 else { throw AccountError.invalidResponse }
        var data = Data()
        for try await byte in stream {
            guard data.count < 65536 else { throw AccountError.invalidResponse }
            data.append(byte)
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                if let bearer, bearer == sessionToken { invalidateSession() }
                throw AccountError.signInRequired
            }
            if http.statusCode == 429 { throw AccountError.tryLater }
            throw AccountError.unavailable
        }
        return data
    }
    private func keychainQuery() -> [String: Any] {
        Self.sessionKeychainQuery()
    }
    private func readSessionData() -> Data? {
        var query = keychainQuery(); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
    private func saveSession(_ session: SavedSession) throws {
        let encoded = try JSONEncoder().encode(session), query = keychainQuery()
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: encoded] as CFDictionary)
        if result == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = encoded
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AccountError.secureStorage }
        } else if result != errSecSuccess { throw AccountError.secureStorage }
    }
    nonisolated private static func validToken(_ value: String) -> Bool {
        value.utf8.count == 43 && value.unicodeScalars.allSatisfy {
            (65...90).contains($0.value) || (97...122).contains($0.value) || (48...57).contains($0.value) || $0 == "_" || $0 == "-"
        }
    }
    nonisolated private static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    private enum AccountError: LocalizedError {
        case unavailable, invalidResponse, secureStorage, signInRequired, tryLater
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Your fighter library is temporarily unavailable. Please try again shortly."
            case .invalidResponse: return "The fighter library returned an incomplete response. Please try again."
            case .secureStorage: return "Your sign-in could not be saved securely. Please try again."
            case .signInRequired: return "Sign in again to manage your library. Downloaded fighters are still available."
            case .tryLater: return "Please wait a minute before trying again."
            }
        }
    }
}

extension CustomFighterAccount: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard controller === authorizationController else { return }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              credential.state == expectedState, !credential.user.isEmpty, credential.user.utf8.count <= 512,
              let data = credential.identityToken, data.count <= 12000,
              let token = String(data: data, encoding: .utf8) else {
            pendingAuthorization?.resume(throwing: AccountError.invalidResponse); pendingAuthorization = nil; return
        }
        pendingAuthorization?.resume(returning: AppleIdentity(token: token, userID: credential.user)); pendingAuthorization = nil
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard controller === authorizationController else { return }
        pendingAuthorization?.resume(throwing: error); pendingAuthorization = nil
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private final class CustomFighterAuthRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
