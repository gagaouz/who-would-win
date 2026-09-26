import XCTest
@testable import WhoWouldWin

@MainActor
final class CustomFighterServiceTests: XCTestCase {
    func testPendingRequestPersistsExactKeyAcrossColdStoreAndOwnerIsolation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID().uuidString.lowercased()
        let request = CustomFighterPendingRequest(ownerID: owner, name: "Moon Dragon", idempotencyKey: UUID().uuidString.lowercased(), jobID: nil)
        try CustomFighterPendingStore(rootURL: root).save(request)
        let coldStore = CustomFighterPendingStore(rootURL: root)
        XCTAssertEqual(try coldStore.load(ownerID: owner), request)
        XCTAssertNil(try coldStore.load(ownerID: UUID().uuidString.lowercased()))
        try coldStore.remove(ownerID: owner)
        XCTAssertNil(try coldStore.load(ownerID: owner))
    }

    func testPendingRequestWriteFailureDoesNotPretendToPersist() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not a directory".utf8).write(to: root)
        let request = CustomFighterPendingRequest(ownerID: UUID().uuidString.lowercased(), name: "Moon Dragon", idempotencyKey: UUID().uuidString.lowercased(), jobID: nil)
        XCTAssertThrowsError(try CustomFighterPendingStore(rootURL: root).save(request))
    }

    func testNameNormalizationAndUnicodeLimitsDoNotTruncateIdentity() throws {
        XCTAssertEqual(try CustomFighterService.validatedName("  Moon Dragon  "), "Moon Dragon")
        XCTAssertEqual(try CustomFighterService.validatedName("Cafe\u{301} Dragon"), "Café Dragon")
        XCTAssertThrowsError(try CustomFighterService.validatedName(String(repeating: "a", count: 25)))
        XCTAssertThrowsError(try CustomFighterService.validatedName("Moon\nDragon"))
        XCTAssertThrowsError(try CustomFighterService.validatedName("  "))
    }

    func testReconcilingJobIsTerminalWhileActualWorkerStatesRemainActive() throws {
        let base = #"{"id":"e8a8c86c-9dc9-444b-9a90-fa57814ab3a7","name":"Moon Dragon","state":"reconciling","createdAt":"2026-09-26T20:00:00.123Z","updatedAt":"2026-09-26T20:00:02Z"}"#
        let job = try CustomFighterService.decoder().decode(CustomFighterJob.self, from: Data(base.utf8))
        XCTAssertFalse(job.isActive)
        XCTAssertEqual(job.label, "Artwork could not be confirmed")
        XCTAssertEqual(job.name, "Moon Dragon")
        for state in ["queued", "generating", "validating"] {
            let active = base.replacingOccurrences(of: "reconciling", with: state)
            XCTAssertTrue(try CustomFighterService.decoder().decode(CustomFighterJob.self, from: Data(active.utf8)).isActive)
        }
        let uncertainMessage = CustomFighterRequestFailure(code: "provider_uncertain").localizedDescription
        XCTAssertTrue(uncertainMessage.contains("credit was returned"))
        XCTAssertTrue(uncertainMessage.contains("will not retry"))
        XCTAssertTrue(uncertainMessage.contains("new grown-up confirmation"))
        let rejected = base.replacingOccurrences(of: "reconciling", with: "rejected")
        XCTAssertFalse(try CustomFighterService.decoder().decode(CustomFighterJob.self, from: Data(rejected.utf8)).isActive)
        XCTAssertThrowsError(try CustomFighterService.decoder().decode(CustomFighterJob.self, from: Data(base.replacingOccurrences(of: "2026-09-26T20:00:02Z", with: "invalid-date").utf8)))
    }

    func testUnknownServerErrorNeverDisplaysUntrustedRawMessage() {
        let untrusted = "raw stack trace or secret from upstream"
        XCTAssertFalse(CustomFighterRequestFailure(code: untrusted).localizedDescription.contains(untrusted))
        XCTAssertTrue(CustomFighterRequestFailure(code: "subscription_expired").localizedDescription.contains("Saved fighters still work"))
        XCTAssertTrue(CustomFighterRequestFailure(code: "quality_rejected").localizedDescription.contains("did not use"))
    }
}
