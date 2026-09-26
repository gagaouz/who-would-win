import Foundation
import Combine
import CryptoKit

struct CustomFighterAllowance: Codable, Equatable {
    let limit: Int
    let used: Int
    let reserved: Int
    let remaining: Int
    let periodKey: String
}

struct CustomFighterServiceStatus: Decodable {
    let enabled: Bool
    let configured: Bool
    let monthlyAllowance: Int
    let requiresSubscription: Bool
    var allowance: CustomFighterAllowance?
    var activeSubscription: Bool?
}

struct CustomFighterJob: Codable, Identifiable, Equatable {
    let id: String
    let state: String
    let name: String
    let assetId: String?
    let errorCode: String?
    let createdAt: Date
    let updatedAt: Date

    var isActive: Bool { ["queued", "generating", "validating"].contains(state) }
    var label: String {
        switch state {
        case "queued": return "Waiting to start"
        case "generating": return "Drawing your fighter"
        case "validating": return "Checking the artwork"
        case "reconciling": return "Artwork could not be confirmed"
        case "ready": return "Artwork ready"
        case "rejected": return "Artwork could not be approved"
        case "cancelled": return "Request cancelled"
        default: return "Artwork could not be completed"
        }
    }
}

struct RemoteCustomFighter: Decodable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    let appearance: CustomFighterAppearanceRef
    let manifest: CustomFighterPackManifest
    let sheetPath: String

    var fighter: CustomFighter { CustomFighter(id: id, name: name, createdAt: createdAt, appearance: appearance) }
}

struct CustomFighterRequestFailure: Error, LocalizedError {
    let code: String
    var errorDescription: String? {
        switch code {
        case "sign_in_required": return "Ask a grown-up to sign in to your fighter account."
        case "subscription_required", "subscription_expired": return "An active Premium subscription is needed to create new artwork. Saved fighters still work."
        case "feature_disabled", "provider_unavailable", "budget_exhausted": return "New artwork is temporarily unavailable. Your saved fighters still work. Try again later."
        case "quota_exhausted": return "This month's artwork allowance is used. Saved fighters are still ready to play."
        case "job_active": return "Another artwork request is in progress. Open its progress below."
        case "name_not_allowed", "content_rejected": return "Try a different, family-friendly creature name. Do not include personal information."
        case "quality_rejected": return "The artwork did not pass its checks. This request did not use an artwork credit."
        case "name_length": return "Use a creature name with 1 to 24 characters."
        case "provider_uncertain": return "The artwork could not be confirmed. Your artwork credit was returned. This request will not retry. A new creation needs a new grown-up confirmation."
        case "idempotency_conflict": return "This saved request does not match the server. Refresh your library before creating again."
        case "local_storage": return "The artwork could not be updated on this device. Please free some space or try again."
        case "invalid_artwork": return "The downloaded artwork could not be verified. Your existing fighters are unchanged."
        case "not_found", "deleted": return "This fighter is no longer available in this account."
        case "cancelled": return "This artwork request was cancelled."
        default: return "Could not connect to your fighter library. Your saved fighters still work. Refresh to try again."
        }
    }
}

struct CustomFighterPendingRequest: Codable, Equatable {
    let ownerID: String
    let name: String
    let idempotencyKey: String
    var jobID: String?
}

/// A request is written atomically before any paid creation is submitted. This
/// store contains no bearer token or receipt and is separate from image caches.
struct CustomFighterPendingStore {
    let rootURL: URL
    init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomFighterRequests/v1", isDirectory: true)
    }
    private func file(_ owner: String) -> URL {
        let digest = SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined()
        return rootURL.appendingPathComponent(digest + ".json")
    }
    func load(ownerID: String) throws -> CustomFighterPendingRequest? {
        let target = file(ownerID)
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        let values = try target.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 4096 else { throw CustomFighterRequestFailure(code: "local_storage") }
        let record = try JSONDecoder().decode(CustomFighterPendingRequest.self, from: Data(contentsOf: target))
        guard record.ownerID == ownerID, UUID(uuidString: record.idempotencyKey) != nil else { throw CustomFighterRequestFailure(code: "local_storage") }
        return record
    }
    func save(_ record: CustomFighterPendingRequest) throws {
        guard UUID(uuidString: record.ownerID) != nil, UUID(uuidString: record.idempotencyKey) != nil else { throw CustomFighterRequestFailure(code: "local_storage") }
        let data = try JSONEncoder().encode(record)
        guard data.count <= 4096 else { throw CustomFighterRequestFailure(code: "local_storage") }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        guard try rootURL.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CustomFighterRequestFailure(code: "local_storage") }
        try data.write(to: file(record.ownerID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func remove(ownerID: String) throws {
        let target = file(ownerID)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
    }
    func eraseAll() throws {
        if FileManager.default.fileExists(atPath: rootURL.path) { try FileManager.default.removeItem(at: rootURL) }
    }
}

/// Owns account-scoped jobs independently of any presented sheet. Generation is
/// started only by create(name:); typing, refresh and preview never create jobs.
@MainActor
final class CustomFighterService: ObservableObject {
    static let shared = CustomFighterService()
    @Published private(set) var status: CustomFighterServiceStatus?
    @Published private(set) var remoteFighters: [RemoteCustomFighter] = []
    @Published private(set) var jobs: [CustomFighterJob] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isCreating = false
    @Published private(set) var downloadingIDs: Set<String> = []
    @Published private(set) var message: String?
    @Published private(set) var hasUnconfirmedRequest = false

    private struct LibraryResponse: Decodable { let fighters: [RemoteCustomFighter]; let jobs: [CustomFighterJob]; let removedAssetIDs: [String]; let libraryEpoch: Int }
    private struct JobResponse: Decodable { let job: CustomFighterJob; let fighter: RemoteCustomFighter?; let allowance: CustomFighterAllowance? }
    #if DEBUG
    @Published private(set) var fixtureCreateCount = 0
    private var fixture: CustomFighterUITestBackend?
    var isUITestFixture: Bool { fixture != nil && AppConfig.isUITesting && AppConfig.isIsolatedTestBuild }
    static func prepareUITestFixture(screen: String) {
        guard AppConfig.isUITesting, AppConfig.isIsolatedTestBuild, CustomFighterUITestBackend.screens.contains(screen) else { return }
        do {
            let fixture = try CustomFighterUITestBackend(screen: screen)
            shared.fixture = fixture
            if ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
                guard shared.clearLocalState() else { assertionFailure("Fixture request reset failed"); return }
                try CustomFighterLibraryStore.shared.eraseAllLocalData()
            }
            if let request = fixture.savedPendingRequest { try shared.pendingStore.save(request) }
            CustomFighterAccount.shared.prepareUITestSession(accountID: fixture.ownerID)
            try CustomFighterLibraryStore.shared.setOwner(ownerID: fixture.ownerID)
            if screen == "custom-fighters-saved" {
                try CustomFighterLibraryStore.shared.install(manifest: fixture.remote.manifest, pngData: fixture.png, fighter: fixture.remote.fighter, forOwner: fixture.ownerID)
            }
        } catch { assertionFailure("Custom fighter fixture failed: \(error)") }
    }
    #endif
    private var servicesAvailable: Bool {
        #if DEBUG
        if isUITestFixture { return true }
        #endif
        return AppConfig.externalServicesEnabled
    }
    private var ownerID: String?
    private var observedToken: String?
    private var pending: CustomFighterPendingRequest?
    private let pendingStore = CustomFighterPendingStore()
    private var accountObservation: AnyCancellable?
    private var pollTask: Task<Void, Never>?
    private var createTask: Task<Void, Never>?
    private let redirectGuard = CustomFighterRedirectGuard()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
    }()

    private init() {
        let account = CustomFighterAccount.shared
        accountObservation = account.$accountID.combineLatest(account.$sessionToken).sink { [weak self] owner, token in
            Task { @MainActor in self?.accountChanged(owner: owner, token: token) }
        }
    }

    var canCreate: Bool {
        CustomFighterAccount.shared.isSignedIn && ownerID != nil && status?.enabled == true && status?.configured == true
            && status?.activeSubscription == true && (status?.allowance?.remaining ?? 0) > 0
            && !isCreating && !jobs.contains(where: \.isActive) && pending == nil
    }

    static func validatedName(_ raw: String) throws -> String {
        let name = raw.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...24).contains(name.unicodeScalars.count), name.utf8.count <= 200,
              name.rangeOfCharacter(from: .controlCharacters) == nil else { throw CustomFighterRequestFailure(code: "name_length") }
        guard ContentFilter.isAppropriate(name) else { throw CustomFighterRequestFailure(code: "name_not_allowed") }
        return name
    }

    func clearMessage() { message = nil }

    /// Local reset never claims to cancel a provider request or delete the online account.
    @discardableResult
    func clearLocalState() -> Bool {
        pollTask?.cancel(); pollTask = nil
        createTask?.cancel(); createTask = nil
        ownerID = nil; observedToken = nil; pending = nil
        jobs = []; remoteFighters = []; status = nil; downloadingIDs = []
        isCreating = false; isRefreshing = false; hasUnconfirmedRequest = false; message = nil
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("customFighters.pending.") || key.hasPrefix("customFighters.epoch.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        do { try pendingStore.eraseAll(); return true }
        catch { message = userMessage(error); return false }
    }

    private func accountChanged(owner: String?, token: String?) {
        guard owner == CustomFighterAccount.shared.accountID, token == CustomFighterAccount.shared.sessionToken else { return }
        guard owner != ownerID || token != observedToken else { return }
        let changedOwner = owner != ownerID
        ownerID = owner; observedToken = token
        pollTask?.cancel(); pollTask = nil
        createTask?.cancel(); createTask = nil
        isCreating = false; isRefreshing = false
        if token == nil { status = nil }
        if changedOwner {
            remoteFighters = []; jobs = []; status = nil; message = nil; downloadingIDs = []
            pending = owner.flatMap(loadPending)
            hasUnconfirmedRequest = pending?.jobID == nil && pending != nil
            do { try CustomFighterLibraryStore.shared.setOwner(ownerID: owner) }
            catch { message = "Your local library could not be opened. Please try again." }
        }
        if owner != nil && token != nil { Task { await refresh() } }
    }

    /// Also safe offline: refresh never discards installed fighters.
    func refresh() async {
        guard !isRefreshing else { return }
        guard servicesAvailable else {
            message = "The artwork service is unavailable in this isolated test session."
            return
        }
        let owner = ownerID
        isRefreshing = true
        defer { if owner == ownerID { isRefreshing = false } }
        do {
            let publicStatus: CustomFighterServiceStatus = try await json("/status", authenticated: false)
            guard owner == ownerID else { return }
            status = publicStatus
            guard let owner, CustomFighterAccount.shared.isSignedIn else { return }
            let library: LibraryResponse = try await json("", owner: owner)
            guard owner == ownerID else { return }
            guard library.fighters.count <= 100 && library.jobs.count <= 30 else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
            try library.fighters.forEach(validateRemote)
            guard library.jobs.allSatisfy({ UUID(uuidString: $0.id) != nil }) else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
            guard library.libraryEpoch > 0, library.removedAssetIDs.count <= 10_000,
                  library.removedAssetIDs.allSatisfy({ UUID(uuidString: $0) != nil }) else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
            let epochKey = "customFighters.epoch." + ownerDigest(owner)
            let previousEpoch = UserDefaults.standard.object(forKey: epochKey) as? Int
            let store = CustomFighterLibraryStore.shared
            if let previousEpoch, previousEpoch != library.libraryEpoch {
                // A server-confirmed account reset revokes this owner's old local
                // roster. Other owners and ordinary absent list entries are untouched.
                for fighter in store.fighters { try store.remove(fighterID: fighter.id) }
                clearPending()
            }
            for id in library.removedAssetIDs { try store.remove(fighterID: id) }
            UserDefaults.standard.set(library.libraryEpoch, forKey: epochKey)
            remoteFighters = library.fighters; jobs = library.jobs
            message = nil
            // The recent list contains only 30 jobs. A durable older request must
            // be resolved directly before checking eligibility for new artwork.
            try await reconcilePendingJob(owner: owner)
            guard owner == ownerID else { return }
            let proof = try await CustomFighterAccount.shared.refreshSubscriptionJWS()
            let authenticated: CustomFighterServiceStatus = try await json("/status", method: "POST", body: proof.map { ["signedTransaction": $0] } ?? [:], owner: owner)
            guard owner == ownerID else { return }
            status = authenticated
            startPolling()
        } catch {
            guard owner == ownerID else { return }
            message = userMessage(error)
            startPolling()
        }
    }

    /// Absence from the recent list is not a terminal state. Only an explicit
    /// missing-job response or a resolved terminal job clears its durable key.
    private func reconcilePendingJob(owner: String) async throws {
        guard let request = pending, request.ownerID == owner, let jobID = request.jobID else { return }
        var resolved = jobs.first { $0.id == jobID }
        var fighter = remoteFighters.first { $0.id == resolved?.assetId }
        if resolved == nil || (resolved?.state == "ready" && fighter == nil) {
            do {
                let response: JobResponse = try await json("/jobs/\(try validID(jobID))", owner: owner)
                guard owner == ownerID, pending?.jobID == jobID, !Task.isCancelled else { return }
                guard response.job.id.lowercased() == jobID.lowercased() else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
                if let remote = response.fighter {
                    try validateRemote(remote)
                    guard remote.id == response.job.assetId else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
                }
                resolved = response.job; fighter = response.fighter
                upsert(response.job)
            } catch let failure as CustomFighterRequestFailure where failure.code == "not_found" {
                guard owner == ownerID, pending?.jobID == jobID else { return }
                clearPending()
                message = "This saved artwork request is no longer available. Your downloaded fighters are unchanged."
                return
            }
        }
        guard owner == ownerID, pending?.jobID == jobID, let resolved, !resolved.isActive else { return }
        if resolved.state == "ready", let fighter {
            // Keep validated metadata visible if the sheet download needs retrying.
            try validateRemote(fighter)
            if !remoteFighters.contains(where: { $0.id == fighter.id }) { remoteFighters.insert(fighter, at: 0) }
            await download(fighter)
        }
        guard owner == ownerID, pending?.jobID == jobID else { return }
        clearPending()
        if let code = resolved.errorCode { message = CustomFighterRequestFailure(code: code).localizedDescription }
    }

    /// Called only after the parent gate and explicit provider-disclosure confirmation.
    func create(name raw: String) {
        guard canCreate, let owner = ownerID else { return }
        do {
            let name = try Self.validatedName(raw)
            let request = CustomFighterPendingRequest(ownerID: owner, name: name, idempotencyKey: UUID().uuidString.lowercased(), jobID: nil)
            try pendingStore.save(request)
            pending = request; hasUnconfirmedRequest = true; submit(request)
        } catch { message = userMessage(error) }
    }

    /// Reuses the exact durable idempotency key after an ambiguous network result.
    func resumeRequest() {
        guard !isCreating else { return }
        if let pending, pending.ownerID == ownerID, pending.jobID == nil { submit(pending) }
        else { Task { await refresh() } }
    }

    private func submit(_ request: CustomFighterPendingRequest) {
        isCreating = true; message = nil
        createTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.ownerID == request.ownerID { self.isCreating = false } }
            do {
                let proof = try await CustomFighterAccount.shared.refreshSubscriptionJWS()
                let response: JobResponse = try await self.json("", method: "POST", body: ["name": request.name, "idempotencyKey": request.idempotencyKey, "signedTransaction": proof ?? "", "consentVersion": "custom-art-v1"], owner: request.ownerID)
                guard !Task.isCancelled, self.ownerID == request.ownerID, UUID(uuidString: response.job.id) != nil else { return }
                self.upsert(response.job)
                self.pending?.jobID = response.job.id; try self.savePending()
                self.status?.allowance = response.allowance
                if response.job.state == "ready", let fighter = response.fighter { await self.download(fighter) }
                if !response.job.isActive { self.clearPending() }
                self.startPolling()
            } catch {
                guard !Task.isCancelled, self.ownerID == request.ownerID else { return }
                if let failure = error as? CustomFighterRequestFailure,
                   ["name_not_allowed", "name_length", "subscription_required", "quota_exhausted", "feature_disabled", "provider_unavailable", "budget_exhausted", "job_active", "idempotency_conflict"].contains(failure.code) {
                    self.clearPending()
                }
                self.message = self.userMessage(error)
            }
        }
    }

    private func startPolling() {
        guard pollTask == nil, let owner = ownerID, CustomFighterAccount.shared.isSignedIn, jobs.contains(where: \.isActive), servicesAvailable else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.ownerID == owner { self.pollTask = nil } }
            for _ in 0..<200 {
                guard !Task.isCancelled, self.ownerID == owner, let job = self.jobs.first(where: \.isActive) else { return }
                do {
                    let response: JobResponse = try await self.json("/jobs/\(try self.validID(job.id))", owner: owner)
                    guard !Task.isCancelled, self.ownerID == owner else { return }
                    self.upsert(response.job)
                    if response.job.state == "ready", let fighter = response.fighter { await self.download(fighter) }
                    if !response.job.isActive {
                        if self.pending?.jobID == response.job.id { self.clearPending() }
                        await self.refresh()
                        if !Task.isCancelled, self.ownerID == owner, let code = response.job.errorCode {
                            self.message = CustomFighterRequestFailure(code: code).localizedDescription
                        }
                        continue
                    }
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    if !Task.isCancelled, self.ownerID == owner { self.message = self.userMessage(error) }
                    return
                }
            }
            self.message = "Your request is saved. Refresh to check its progress."
        }
    }

    func download(_ remote: RemoteCustomFighter) async {
        guard let owner = ownerID, !downloadingIDs.contains(remote.id) else { return }
        downloadingIDs.insert(remote.id)
        defer { if owner == ownerID { downloadingIDs.remove(remote.id) } }
        do {
            try validateRemote(remote)
            let bytes = try await data("/\(try validID(remote.id))/sheet", owner: owner, maximumBytes: 8 * 1024 * 1024, png: true)
            guard owner == ownerID, !Task.isCancelled else { return }
            try CustomFighterLibraryStore.shared.install(manifest: remote.manifest, pngData: bytes, fighter: remote.fighter, forOwner: owner)
            if !remoteFighters.contains(where: { $0.id == remote.id }) { remoteFighters.insert(remote, at: 0) }
        } catch { if owner == ownerID { message = userMessage(error) } }
    }

    func delete(_ fighter: CustomFighter) async {
        guard let owner = ownerID else { return }
        do {
            do { _ = try await data("/\(try validID(fighter.id))", method: "DELETE", owner: owner) }
            catch let failure as CustomFighterRequestFailure where failure.code == "not_found" { /* Already removed remotely; finish local deletion. */ }
            guard owner == ownerID else { return }
            try CustomFighterLibraryStore.shared.remove(fighterID: fighter.id)
            remoteFighters.removeAll { $0.id == fighter.id }
            message = "Fighter deleted. Deleting does not restore an artwork credit."
        } catch { if owner == ownerID { message = userMessage(error) } }
    }

    func report(_ fighter: CustomFighter, reason: String) async {
        guard let owner = ownerID, ["unsafe", "wrong_subject", "poor_quality", "other"].contains(reason) else { return }
        do {
            _ = try await data("/\(try validID(fighter.id))/report", method: "POST", body: ["reason": reason], owner: owner)
            guard owner == ownerID else { return }
            if reason == "unsafe" {
                try CustomFighterLibraryStore.shared.remove(fighterID: fighter.id)
                remoteFighters.removeAll { $0.id == fighter.id }
                message = "The unsafe artwork was reported and removed from this library."
            } else {
                message = "Thank you. The artwork report was sent."
            }
        } catch { if owner == ownerID { message = userMessage(error) } }
    }

    private func validateRemote(_ remote: RemoteCustomFighter) throws {
        let id = try validID(remote.id)
        guard remote.fighter.isValid, remote.appearance == remote.manifest.appearance,
              remote.sheetPath == "/api/custom-fighters/\(id)/sheet" else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
    }

    private func upsert(_ job: CustomFighterJob) {
        jobs.removeAll { $0.id == job.id }; jobs.insert(job, at: 0)
    }
    private func ownerDigest(_ owner: String) -> String { SHA256.hash(data: Data(owner.utf8)).map { String(format: "%02x", $0) }.joined() }
    private func loadPending(_ owner: String) -> CustomFighterPendingRequest? {
        do { return try pendingStore.load(ownerID: owner) }
        catch { message = userMessage(error); return nil }
    }
    private func savePending() throws {
        if let pending { try pendingStore.save(pending) }
        hasUnconfirmedRequest = pending?.jobID == nil && pending != nil
    }
    private func clearPending() {
        do { if let pending { try pendingStore.remove(ownerID: pending.ownerID) } }
        catch { message = userMessage(error); return }
        pending = nil; hasUnconfirmedRequest = false
    }
    private func validID(_ value: String) throws -> String {
        guard let uuid = UUID(uuidString: value), uuid.uuidString.lowercased() == value.lowercased() else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
        return uuid.uuidString.lowercased()
    }
    private func userMessage(_ error: Error) -> String {
        if let failure = error as? CustomFighterRequestFailure { return failure.localizedDescription }
        if let failure = error as? CustomFighterLibraryStore.StorageError { return failure.localizedDescription }
        if (error as NSError).domain == NSCocoaErrorDomain { return CustomFighterRequestFailure(code: "local_storage").localizedDescription }
        return CustomFighterRequestFailure(code: "network").localizedDescription
    }

    private func json<T: Decodable>(_ suffix: String, method: String = "GET", body: [String: String]? = nil, authenticated: Bool = true, owner: String? = nil) async throws -> T {
        let bytes = try await data(suffix, method: method, body: body, authenticated: authenticated, owner: owner)
        return try Self.decoder().decode(T.self, from: bytes)
    }
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid server date")) }
            return date
        }
        return decoder
    }
    private func data(_ suffix: String, method: String = "GET", body: [String: String]? = nil, authenticated: Bool = true, owner: String? = nil, maximumBytes: Int = 1_048_576, png: Bool = false) async throws -> Data {
        #if DEBUG
        if let fixture, isUITestFixture {
            let result = try fixture.respond(suffix: suffix, method: method, body: body)
            fixtureCreateCount = fixture.createCount
            return result
        }
        #endif
        guard AppConfig.externalServicesEnabled else { throw CustomFighterRequestFailure(code: "feature_disabled") }
        guard let url = URL(string: AppConfig.customFighterBaseURL + "/api/custom-fighters" + suffix), url.scheme == "https" else { throw URLError(.badURL) }
        let requestOwner = authenticated ? (owner ?? ownerID) : nil
        let requestToken = authenticated ? CustomFighterAccount.shared.sessionToken : nil
        var request = URLRequest(url: url); request.httpMethod = method; request.timeoutInterval = 35
        request.setValue(png ? "image/png" : "application/json", forHTTPHeaderField: "Accept")
        if authenticated {
            let account = CustomFighterAccount.shared
            guard let expectedOwner = owner ?? ownerID, expectedOwner == account.accountID, expectedOwner == ownerID, let token = account.sessionToken else { throw CustomFighterRequestFailure(code: "sign_in_required") }
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (stream, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.url == url else { throw URLError(.badServerResponse) }
        guard response.expectedContentLength <= Int64(maximumBytes) else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
        var result = Data()
        if response.expectedContentLength > 0 { result.reserveCapacity(min(maximumBytes, Int(response.expectedContentLength))) }
        for try await byte in stream {
            guard result.count < maximumBytes else { throw CustomFighterRequestFailure(code: "invalid_artwork") }
            result.append(byte)
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 {
                let account = CustomFighterAccount.shared
                if let requestOwner, let requestToken, requestOwner == account.accountID, requestToken == account.sessionToken {
                    account.invalidateSession()
                }
                throw CustomFighterRequestFailure(code: "sign_in_required")
            }
            let object = (try? JSONSerialization.jsonObject(with: result)) as? [String: Any]
            throw CustomFighterRequestFailure(code: String((object?["code"] as? String ?? "network").prefix(64)))
        }
        if png { guard response.mimeType == "image/png" else { throw CustomFighterRequestFailure(code: "invalid_artwork") } }
        return result
    }
}

private final class CustomFighterRedirectGuard: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
