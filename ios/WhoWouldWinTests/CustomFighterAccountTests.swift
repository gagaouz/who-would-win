import XCTest
import Security
@testable import WhoWouldWin

final class CustomFighterAccountTests: XCTestCase {
    private let owner = "920c5c56-776d-4efa-8b35-79ff1c1c39e1"
    private let token = String(repeating: "a", count: 43)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAllAccountOperationsStayOnDedicatedLibraryOrigin() throws {
        let library = "https://library.example.test"
        let battle = "https://battles.example.test"
        let configuration = CustomFighterAccount.BackendConfiguration(battleBaseURL: battle, customFighterBaseURL: library)
        for path in ["challenge", "apple", "signout", "account"] {
            let url = try XCTUnwrap(CustomFighterAccount.authenticationURL(for: path, configuration: configuration))
            XCTAssertEqual(url.absoluteString, library + "/api/custom-fighters/auth/" + path)
            XCTAssertNotEqual(url.host, URL(string: battle)?.host)
            let trailingSlash = CustomFighterAccount.BackendConfiguration(battleBaseURL: battle, customFighterBaseURL: library + "/")
            XCTAssertEqual(CustomFighterAccount.authenticationURL(for: path, configuration: trailingSlash), url)
        }
    }

    func testAccountEndpointsRejectUnsafeOriginsAndUnknownPaths() {
        for base in ["http://library.example.test", "https:///", "https://user:password@library.example.test",
                     "https://library.example.test?redirect=other", "https://library.example.test#fragment"] {
            let configuration = CustomFighterAccount.BackendConfiguration(battleBaseURL: "https://battles.example.test", customFighterBaseURL: base)
            XCTAssertNil(CustomFighterAccount.authenticationURL(for: "apple", configuration: configuration), base)
        }
        let configuration = CustomFighterAccount.BackendConfiguration(battleBaseURL: "https://battles.example.test", customFighterBaseURL: "https://library.example.test")
        for path in ["../apple", "apple?redirect=other", "https://other.example.test", "subscription-notifications", ""] {
            XCTAssertNil(CustomFighterAccount.authenticationURL(for: path, configuration: configuration), path)
        }
    }

    func testSessionStorageIsScopedToLibraryDeploymentAndAppBundle() {
        let bundle = "com.example.game"
        let library = "https://library.example.test"
        let configuration = CustomFighterAccount.BackendConfiguration(battleBaseURL: "https://battles.example.test", customFighterBaseURL: library)
        let query = CustomFighterAccount.sessionKeychainQuery(bundleIdentifier: bundle, configuration: configuration)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, library)
        XCTAssertEqual(query[kSecAttrService as String] as? String, bundle + ".fighter-account")
        let trailingSlash = CustomFighterAccount.BackendConfiguration(battleBaseURL: "https://battles.example.test", customFighterBaseURL: library + "/")
        let normalized = CustomFighterAccount.sessionKeychainQuery(bundleIdentifier: bundle, configuration: trailingSlash)
        XCTAssertEqual(normalized[kSecAttrAccount as String] as? String, query[kSecAttrAccount as String] as? String)
        XCTAssertNotEqual(query[kSecAttrAccount as String] as? String, configuration.battleBaseURL)
        let otherLibrary = CustomFighterAccount.BackendConfiguration(battleBaseURL: configuration.battleBaseURL, customFighterBaseURL: "https://another-library.example.test")
        let otherLibraryQuery = CustomFighterAccount.sessionKeychainQuery(bundleIdentifier: bundle, configuration: otherLibrary)
        XCTAssertNotEqual(otherLibraryQuery[kSecAttrAccount as String] as? String, query[kSecAttrAccount as String] as? String)
        let otherBundle = CustomFighterAccount.sessionKeychainQuery(bundleIdentifier: bundle + ".uitesting", configuration: configuration)
        XCTAssertNotEqual(otherBundle[kSecAttrService as String] as? String, query[kSecAttrService as String] as? String)
    }

    func testExpiredLegacySessionPreservesOfflineOwnerButCannotAuthorizeRequests() throws {
        // Original Keychain schema omitted appleUserID and used nonoptional token/expiry.
        let legacy: [String: String] = ["accountID": owner, "sessionToken": token, "expiresAt": "2020-01-01T00:00:00Z"]
        let restored = try XCTUnwrap(CustomFighterAccount.restoreSession(from: JSONEncoder().encode(legacy), now: now))
        XCTAssertEqual(restored.accountID, owner)
        XCTAssertNil(restored.sessionToken)
        XCTAssertNil(restored.expiresAt)
        XCTAssertNil(restored.appleUserID)
        let cold = try XCTUnwrap(CustomFighterAccount.restoreSession(from: JSONEncoder().encode(restored), now: now))
        XCTAssertEqual(cold.accountID, owner)
        XCTAssertNil(cold.sessionToken, "Cold launches must not turn an offline owner back into an authenticated session.")
    }

    func testValidSessionRestoresCredentialIdentityAndRejectsMalformedBearerWithoutLosingFiles() throws {
        let active = CustomFighterAccount.SavedSession(accountID: owner, sessionToken: token,
            expiresAt: "2099-01-01T00:00:00.000Z", appleUserID: "private-apple-user")
        XCTAssertEqual(CustomFighterAccount.restoreSession(from: try JSONEncoder().encode(active), now: now), active)
        let invalid = CustomFighterAccount.SavedSession(accountID: owner, sessionToken: String(repeating: "é", count: 43),
            expiresAt: active.expiresAt, appleUserID: active.appleUserID)
        let offline = try XCTUnwrap(CustomFighterAccount.restoreSession(from: JSONEncoder().encode(invalid), now: now))
        XCTAssertEqual(offline.accountID, owner)
        XCTAssertEqual(offline.appleUserID, active.appleUserID)
        XCTAssertNil(offline.sessionToken)
    }

    func testCorruptOrOversizedAccountRecordsCannotInventAnOwner() throws {
        let bad = CustomFighterAccount.SavedSession(accountID: "../../another-owner", sessionToken: token,
            expiresAt: "2099-01-01T00:00:00Z", appleUserID: nil)
        XCTAssertNil(CustomFighterAccount.restoreSession(from: try JSONEncoder().encode(bad), now: now))
        XCTAssertNil(CustomFighterAccount.restoreSession(from: Data(repeating: 65, count: 16_385), now: now))
        XCTAssertNil(CustomFighterAccount.restoreSession(from: Data("not json".utf8), now: now))
    }
}
