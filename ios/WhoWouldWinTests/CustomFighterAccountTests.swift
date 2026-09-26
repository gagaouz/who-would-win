import XCTest
@testable import WhoWouldWin

final class CustomFighterAccountTests: XCTestCase {
    private let owner = "920c5c56-776d-4efa-8b35-79ff1c1c39e1"
    private let token = String(repeating: "a", count: 43)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

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
