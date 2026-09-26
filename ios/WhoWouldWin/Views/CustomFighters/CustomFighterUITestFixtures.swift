#if DEBUG
import UIKit
import CryptoKit

/// Explicit local-only test backend. No request is sent, no paid entitlement is
/// minted, and its session never enters Keychain or a Release binary.
@MainActor
final class CustomFighterUITestBackend {
    static let screens = ["custom-fighters-ready", "custom-fighters-unavailable", "custom-fighters-saved", "custom-fighters-resume"]
    let ownerID = "3f3d830a-431a-4a4b-9ba7-57f7cce18b92"
    let remote: RemoteCustomFighter
    let png: Data
    private let screen: String
    private(set) var createCount = 0
    private var recordedKey: String?
    private var createdName = "Test Moon Lion"
    private let jobID = "2baf2178-89ca-4ec8-a112-3439bd657b6d"

    var savedPendingRequest: CustomFighterPendingRequest? {
        guard screen == "custom-fighters-resume" else { return nil }
        return CustomFighterPendingRequest(ownerID: ownerID, name: createdName,
            idempotencyKey: "6cf3ae22-4889-43da-9d8a-09682bf4a9f8", jobID: jobID)
    }

    init(screen: String) throws {
        precondition(AppConfig.isUITesting && AppConfig.isIsolatedTestBuild)
        self.screen = screen
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024), format: format)
        png = renderer.pngData { context in
            context.cgContext.interpolationQuality = .none
            for (index, pose) in RetroPose.allCases.enumerated() {
                if let image = RetroAssetStore.shared.image(for: Animals.lion, pose: pose) {
                    let scale = min(400 / image.size.width, 400 / image.size.height)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let origin = CGPoint(x: CGFloat(index % 2) * 512 + (512 - size.width) / 2,
                                         y: CGFloat(index / 2) * 512 + (512 - size.height) / 2)
                    image.draw(in: CGRect(origin: origin, size: size))
                }
            }
        }
        let assetID = "ab70d157-1469-4c43-bfb6-005b53f21b77"
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let manifest = CustomFighterPackManifest(schemaVersion: 1, assetID: assetID, version: 1, sha256: digest,
            styleVersion: "retro-v1", width: 1024, height: 1024, archetype: "quadruped",
            frames: ["idle": [0,0,512,512], "anticipation": [512,0,512,512], "attack": [0,512,512,512], "reaction": [512,512,512,512]])
        remote = RemoteCustomFighter(id: assetID, name: "Test Moon Lion", createdAt: Date(timeIntervalSince1970: 1_700_000_000), appearance: manifest.appearance,
                                    manifest: manifest, sheetPath: "/api/custom-fighters/\(assetID)/sheet")
    }

    func respond(suffix: String, method: String, body: [String: String]?) throws -> Data {
        precondition(AppConfig.isUITesting && AppConfig.isIsolatedTestBuild)
        let enabled = screen != "custom-fighters-unavailable"
        let eligible = screen == "custom-fighters-ready"
        let allowance: [String: Any] = ["limit": 3, "used": createCount, "reserved": 0,
                                       "remaining": eligible ? max(0, 3-createCount) : 0, "periodKey": "TEST-ONLY"]
        if suffix == "/status" {
            return try encoded(["enabled": enabled, "configured": enabled, "monthlyAllowance": 3,
                                "requiresSubscription": true, "activeSubscription": eligible, "allowance": allowance])
        }
        if suffix == "", method == "POST" {
            guard enabled else { throw CustomFighterRequestFailure(code: "feature_disabled") }
            guard eligible else { throw CustomFighterRequestFailure(code: "subscription_required") }
            guard body?["consentVersion"] == "custom-art-v1", let key = body?["idempotencyKey"], UUID(uuidString: key) != nil else { throw CustomFighterRequestFailure(code: "name_not_allowed") }
            if recordedKey == nil { recordedKey = key; createdName = body?["name"] ?? "Test Moon Lion"; createCount += 1 }
            else if recordedKey != key { throw CustomFighterRequestFailure(code: "quota_exhausted") }
            return try encoded(["job": job(), "fighter": fighter(), "allowance": ["limit": 3, "used": 1, "reserved": 0, "remaining": 2, "periodKey": "TEST-ONLY"]])
        }
        if suffix == "", method == "GET" {
            return try encoded(["fighters": screen == "custom-fighters-saved" || createCount > 0 ? [fighter()] : [],
                                "jobs": createCount > 0 ? [job()] : [], "removedAssetIDs": [], "libraryEpoch": 1])
        }
        if suffix == "/\(remote.id)/sheet" { return png }
        if suffix == "/jobs/\(jobID)" { return try encoded(["job": job(), "fighter": fighter()]) }
        if method == "DELETE" || suffix.hasSuffix("/report") { return Data() }
        throw CustomFighterRequestFailure(code: "not_found")
    }
    private func fighter() -> [String: Any] {
        ["id": remote.id, "name": createdName, "createdAt": "2023-11-14T22:13:20.000Z",
         "appearance": ["schemaVersion": 1, "assetID": remote.appearance.assetID, "version": 1, "sha256": remote.appearance.sha256],
         "manifest": ["schemaVersion": 1, "assetID": remote.manifest.assetID, "version": 1, "sha256": remote.manifest.sha256,
                      "styleVersion": "retro-v1", "width": 1024, "height": 1024, "archetype": "quadruped", "frames": remote.manifest.frames],
         "sheetPath": remote.sheetPath]
    }
    private func job() -> [String: Any] {
        ["id": jobID, "name": createdName, "state": "ready", "assetId": remote.id,
         "createdAt": "2023-11-14T22:13:20.000Z", "updatedAt": "2023-11-14T22:13:20.000Z"]
    }
    private func encoded(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
}
#endif
