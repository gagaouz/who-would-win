import Foundation
import CryptoKit
import DeviceCheck

enum AnonymousRequestIdentity {
    private static let installIDKey = "anonymousInstallID"

    static var installID: String {
        if let existing = UserDefaults.standard.string(forKey: installIDKey),
           UUID(uuidString: existing) != nil { return existing.lowercased() }
        let created = UUID().uuidString.lowercased()
        UserDefaults.standard.set(created, forKey: installIDKey)
        return created
    }

    static func apply(to request: inout URLRequest) {
        request.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Request-ID")
        request.setValue(installID, forHTTPHeaderField: "X-Install-ID")
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            request.setValue(version, forHTTPHeaderField: "X-App-Version")
        }
    }
}

actor AppAttestManager {
    static let shared = AppAttestManager()
    private let keyIDStorageKey = "appAttestKeyID"
    private var retryAfter = Date.distantPast

    struct PreparedBody {
        let data: Data
        let authentication: String?
    }

    func prepare(_ original: [String: Any]) async -> PreparedBody {
        guard DCAppAttestService.shared.isSupported, Date() >= retryAfter else {
            return unsigned(original)
        }
        do {
            let keyID = try await registeredKeyID()
            let challenge = try await fetchChallenge()
            var body = original
            body["attestChallenge"] = challenge
            let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            let hash = Data(SHA256.hash(data: data))
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: hash)
            let envelope = try JSONSerialization.data(withJSONObject: [
                "keyId": keyID,
                "assertion": assertion.base64EncodedString(),
            ], options: [.sortedKeys])
            return PreparedBody(data: data, authentication: envelope.base64EncodedString())
        } catch {
            retryAfter = Date().addingTimeInterval(15 * 60)
            return unsigned(original)
        }
    }

    func invalidateKey() {
        UserDefaults.standard.removeObject(forKey: keyIDStorageKey)
        retryAfter = Date.distantPast
    }

    private func unsigned(_ body: [String: Any]) -> PreparedBody {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data("{}".utf8)
        return PreparedBody(data: data, authentication: nil)
    }

    private func registeredKeyID() async throws -> String {
        if let existing = UserDefaults.standard.string(forKey: keyIDStorageKey) { return existing }
        let challenge = try await fetchChallenge()
        let keyID = try await DCAppAttestService.shared.generateKey()
        let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: challengeHash)

        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/attest/register") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AnonymousRequestIdentity.apply(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "keyId": keyID,
            "challenge": challenge,
            "attestation": attestation.base64EncodedString(),
        ], options: [.sortedKeys])
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw URLError(.userAuthenticationRequired) }
        UserDefaults.standard.set(keyID, forKey: keyIDStorageKey)
        return keyID
    }

    private func fetchChallenge() async throws -> String {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/attest/challenge") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AnonymousRequestIdentity.apply(to: &request)
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: String],
              let challenge = object["challenge"] else { throw URLError(.badServerResponse) }
        return challenge
    }
}

actor BattleService {
    static let shared = BattleService()

    private init() {}

    private func secureRequest(url: URL, method: String = "POST", timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AnonymousRequestIdentity.apply(to: &request)
        return request
    }

    // MARK: - Warm-up

    /// Fire-and-forget ping to wake the Railway backend from cold-start. The
    /// container sleeps when idle and a cold boot is ~5–15 s; if the FIRST battle
    /// of a session triggers that boot it can blow past the request timeout and
    /// fall back to the (generic, offline) template — which is exactly what we
    /// never want for a custom creature. Calling this on app launch / when the
    /// picker appears means the backend is already warm by battle time.
    nonisolated func warmUp() {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/health") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Network Battle

    func fetchBattleResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = true, tournamentContext: String? = nil) async throws -> BattleResult {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle") else {
            throw BattleError.serverError
        }

        var request = secureRequest(url: url, timeout: 25)
        // 25s gives the Railway backend room for a cold-start (~5–15 s) plus
        // a few seconds of LLM round-trip without prematurely tripping the
        // offline fallback. Anything tighter than this misclassifies legit
        // slow-but-working responses as "offline".

        var body: [String: Any] = [
            "fighter1": fighter1.id,
            "fighter2": fighter2.id,
            "fighter1Name": fighter1.name,
            "fighter2Name": fighter2.name,
        ]
        // Only send environment fields when arena effects are explicitly enabled.
        // Omitting them entirely tells the backend to use neutral logic —
        // no terrain advantage or disadvantage for either animal.
        if arenaEffectsEnabled {
            body["environment"]     = environment.rawValue
            body["environmentName"] = environment.name
        }
        // Tournament context: a short server-trusted string describing the round
        // (the backend keys its story cache on it, so finals read differently).
        if let tournamentContext, !tournamentContext.isEmpty {
            body["tournamentContext"] = tournamentContext
        }
        let prepared = await AppAttestManager.shared.prepare(body)
        request.httpBody = prepared.data
        if let authentication = prepared.authentication {
            request.setValue(authentication, forHTTPHeaderField: "X-App-Attest")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BattleError.serverError
            }
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(BattleResult.self, from: data)
            case 401:
                await AppAttestManager.shared.invalidateKey()
                throw BattleError.serverError
            case 429:
                throw BattleError.rateLimited
            default:
                throw BattleError.serverError
            }
        } catch let error as BattleError {
            throw error
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut, .dnsLookupFailed:
                throw BattleError.networkUnavailable
            default:
                throw BattleError.serverError
            }
        } catch {
            throw BattleError.serverError
        }
    }

    // MARK: - Quick Battle (lightweight AI)

    /// Calls /api/battle/quick — same AI logic but shorter prompt (~4× fewer tokens).
    /// Used by tournament Quick Mode. Never returns a draw.
    /// - Parameter forceNetwork: when true, skip the on-device experiment path
    ///   and always hit the backend (used by the Narration Lab to fetch a true
    ///   cloud result for side-by-side comparison).
    func fetchQuickBattleResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = false, forceNetwork: Bool = false) async throws -> BattleResult {
        // ⚙️ Experiment: on-device narration. When the flag is on AND iOS 26+ AND
        // Apple Intelligence is available, resolve + narrate entirely on device —
        // no network, no cost. Built-in animals only (custom creatures still need
        // the cloud model's broad knowledge). Read the flag straight from
        // UserDefaults to avoid a MainActor hop inside this actor.
        if !forceNetwork, !fighter1.isCustom, !fighter2.isCustom,
           UserDefaults.standard.bool(forKey: UserSettings.onDeviceNarrationKey) {
            if let onDevice = await tryOnDeviceQuickResult(
                fighter1: fighter1, fighter2: fighter2,
                environment: environment, arenaEffectsEnabled: arenaEffectsEnabled) {
                return onDevice
            }
            // Fall through to the network path if on-device wasn't available.
        }

        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle/quick") else {
            throw BattleError.serverError
        }

        var request = secureRequest(url: url, timeout: 25)
        // Quick-mode requests are smaller but still hit the same Railway
        // backend, which can cold-start. Bumped to 30s now that the quick
        // prompt produces 3-sentence cinematic narration (longer to generate
        // than the old 1-sentence version).

        var body: [String: Any] = [
            "fighter1": fighter1.id,
            "fighter2": fighter2.id,
            "fighter1Name": fighter1.name,
            "fighter2Name": fighter2.name,
        ]
        if arenaEffectsEnabled {
            body["environment"]     = environment.rawValue
            body["environmentName"] = environment.name
        }
        let prepared = await AppAttestManager.shared.prepare(body)
        request.httpBody = prepared.data
        if let authentication = prepared.authentication {
            request.setValue(authentication, forHTTPHeaderField: "X-App-Attest")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut, .dnsLookupFailed:
                throw BattleError.networkUnavailable
            default:
                throw BattleError.serverError
            }
        } catch {
            throw BattleError.serverError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BattleError.serverError
        }

        switch httpResponse.statusCode {
        case 200...299: break
        case 401:
            await AppAttestManager.shared.invalidateKey()
            throw BattleError.serverError
        case 429: throw BattleError.rateLimited
        default:  throw BattleError.serverError
        }

        do {
            return try JSONDecoder().decode(BattleResult.self, from: data)
        } catch {
            throw BattleError.serverError
        }
    }

    // MARK: - Melee (N-vs-M team battle)

    /// Calls /api/battle/melee with two teams and an optional environment.
    /// Returns a `MeleeResult` with the winning team, narration, and MVP.
    func fetchMeleeResult(teamA: [Animal], teamB: [Animal],
                          environment: BattleEnvironment = .grassland,
                          arenaEffectsEnabled: Bool = false) async throws -> MeleeResult {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle/melee") else {
            throw BattleError.serverError
        }

        struct FighterDTO: Encodable { let id: String; let name: String? }
        var body: [String: Any] = [
            "teamA": teamA.map { ["id": $0.id, "name": $0.name] },
            "teamB": teamB.map { ["id": $0.id, "name": $0.name] },
        ]
        if arenaEffectsEnabled {
            body["environment"]     = environment.rawValue
            body["environmentName"] = environment.name
        }

        var request = secureRequest(url: url, timeout: 30)
        // 35s — melee prompts are longer than 1v1 (5–7 sentences) so allow more
        // room before falling back to local. Cold-start on Railway can eat
        // 15s of this; 35 keeps us well clear of timeouts during normal play.
        let prepared = await AppAttestManager.shared.prepare(body)
        request.httpBody = prepared.data
        if let authentication = prepared.authentication {
            request.setValue(authentication, forHTTPHeaderField: "X-App-Attest")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .timedOut, .dnsLookupFailed:
                throw BattleError.networkUnavailable
            default: throw BattleError.serverError
            }
        } catch {
            throw BattleError.serverError
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw BattleError.serverError }
        switch httpResponse.statusCode {
        case 200...299: break
        case 401:
            await AppAttestManager.shared.invalidateKey()
            throw BattleError.serverError
        case 429: throw BattleError.rateLimited
        default:  throw BattleError.serverError
        }

        do {
            return try JSONDecoder().decode(MeleeResult.self, from: data)
        } catch {
            throw BattleError.serverError
        }
    }

    /// Offline fallback for melees. DETERMINISTIC and, for all-built-in teams,
    /// the same math as the server's meleeResolver: a team with a god wins;
    /// otherwise each side's `2^(tier) × arena` is summed with a mild
    /// coordination decay (0.92 per extra fighter), and a team that can't
    /// function in the arena loses. Teams with a custom creature compare
    /// arena-adjusted stats instead. MVP is the strongest winner.
    func generateMeleeFallback(teamA: [Animal], teamB: [Animal],
                               environment: BattleEnvironment = .grassland,
                               arenaEffectsEnabled: Bool = true,
                               markAsOffline: Bool = true) -> MeleeResult {
        let allBuiltIn = (teamA + teamB).allSatisfy { OnDeviceTiers.isBuiltIn($0.id) }
        let statEnv: BattleEnvironment = arenaEffectsEnabled ? environment : .grassland
        let scoreFor: (Animal) -> Double = { animal in
            if allBuiltIn {
                return pow(2.0, OnDeviceTiers.effectiveTier(for: animal.id))
                    * OnDeviceResolver.envMod(animal.id, environment, arenaEnabled: arenaEffectsEnabled)
            }
            let s = AnimalStats.generate(for: animal, environment: statEnv)
            return Double(s.speed + s.power + s.agility + s.defense)
        }
        let power: ([Animal]) -> Double = { team in
            team.map(scoreFor).reduce(0, +) * pow(0.92, Double(team.count - 1))
        }
        let avgEnv: ([Animal]) -> Double = { team in
            team.map { OnDeviceResolver.envMod($0.id, environment, arenaEnabled: arenaEffectsEnabled) }
                .reduce(0, +) / Double(max(team.count, 1))
        }

        let aHasGod = teamA.contains { OnDeviceTiers.deities.contains($0.id) }
        let bHasGod = teamB.contains { OnDeviceTiers.deities.contains($0.id) }
        let powerA = power(teamA), powerB = power(teamB)
        let aWins: Bool
        if aHasGod != bHasGod {
            aWins = aHasGod
        } else if allBuiltIn && avgEnv(teamA) <= 0.10 && avgEnv(teamB) >= 0.5 {
            aWins = false
        } else if allBuiltIn && avgEnv(teamB) <= 0.10 && avgEnv(teamA) >= 0.5 {
            aWins = true
        } else {
            aWins = powerA >= powerB   // exact tie → team A, same as the server
        }

        let winnerSide = aWins ? teamA : teamB
        let loserSide  = aWins ? teamB : teamA
        let mvp = winnerSide.max { scoreFor($0) < scoreFor($1) } ?? winnerSide[0]
        let (w, l) = aWins ? (powerA, powerB) : (powerB, powerA)
        let dominance = (w + l) > 0 ? w / (w + l) : 0.55

        let narration = MeleeFallbackStory.narrate(winners: winnerSide, losers: loserSide, mvp: mvp)
        let funFact   = MeleeFallbackStory.funFact(winners: winnerSide, losers: loserSide)
        let winnerHealth = min(90, 55 + Int(dominance * 35))
        let loserHealth = max(8, Int((1 - dominance) * 30))

        return MeleeResult(
            winningTeam: aWins ? .A : .B,
            narration: narration,
            funFact: funFact,
            mvp: mvp.id,
            teamAHealth: aWins ? winnerHealth : loserHealth,
            teamBHealth: aWins ? loserHealth : winnerHealth,
            isOfflineFallback: markAsOffline
        )
    }

    // MARK: - On-Device Narration (experiment)

    /// Produce a full quick-battle result on device: deterministic resolver
    /// picks the winner, Apple Foundation Models writes the story. Returns nil
    /// (so the caller falls back to the network) when unavailable or on error.
    private func tryOnDeviceQuickResult(fighter1: Animal, fighter2: Animal,
                                        environment: BattleEnvironment,
                                        arenaEffectsEnabled: Bool) async -> BattleResult? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return nil }
        guard OnDeviceNarrator.availability.isAvailable else { return nil }

        // 1. Resolver decides the winner (quick mode never draws → re-roll a draw).
        var verdict = OnDeviceResolver.resolve(fighter1, fighter2,
                                               environment: environment,
                                               arenaEffectsEnabled: arenaEffectsEnabled)
        if verdict.isDraw {
            // ONE coin flip — derive the loser from it. (Two independent flips
            // would collide ~50% of the time and make winner == loser, i.e.
            // "Lion defeats Lion".)
            let f1Wins = Bool.random()
            verdict = OnDeviceResolver.Verdict(
                winner: f1Wins ? fighter1 : fighter2,
                loser:  f1Wins ? fighter2 : fighter1,
                isDraw: false, dominance: 0.55)
        }

        // 2. Model narrates the predetermined winner.
        do {
            let story = try await OnDeviceNarrator.shared.narrate(
                winner: verdict.winner, loser: verdict.loser,
                environmentName: arenaEffectsEnabled ? environment.name : nil)
            // Strip emoji BEFORE the empty check (parity with the backend's
            // strip-then-validate): an all-emoji story must fall through to
            // the network, not ship text that displays as a blank card.
            let n = story.narration.withoutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
            let f = story.funFact.withoutEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty, !f.isEmpty else { return nil }
            let dom = verdict.dominance
            return BattleResult(
                winner: verdict.winner.id,
                narration: n,
                funFact: f,
                winnerHealthPercent: min(90, 60 + Int(dom * 30)),   // honor BattleResult's 10–90 contract
                loserHealthPercent: max(5, Int((1 - dom) * 30)))
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Offline / Local Fallback

    /// The phone's own result, used when the cloud can't answer (offline,
    /// server busy, spending cap). DETERMINISTIC, like the server: built-in
    /// creatures go through `OnDeviceResolver` (the same master list and rules
    /// the cloud uses), so the offline winner always matches the online one.
    /// Custom creatures have no tier on the phone, so they compare arena-
    /// adjusted stats — still no dice.
    ///
    /// `markAsOffline` controls whether the result is flagged with
    /// `isOfflineFallback = true`. Pass `true` only when the device is
    /// genuinely offline (no internet); pass `false` when this is a local
    /// fallback for a server slowdown / 5xx / rate-limit so the user does NOT
    /// see a misleading "⚡ Offline result" badge while they're online.
    func generateFallbackResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland,
                                arenaEffectsEnabled: Bool = true, markAsOffline: Bool = true) -> BattleResult {
        let winnerAnimal: Animal
        let loserAnimal: Animal
        let dominance: Double

        if OnDeviceTiers.isBuiltIn(fighter1.id) && OnDeviceTiers.isBuiltIn(fighter2.id) {
            let verdict = OnDeviceResolver.resolve(fighter1, fighter2, environment: environment,
                                                   arenaEffectsEnabled: arenaEffectsEnabled)
            winnerAnimal = verdict.winner
            loserAnimal = verdict.loser
            dominance = verdict.dominance
        } else {
            let statEnv: BattleEnvironment = arenaEffectsEnabled ? environment : .grassland
            let stats1 = AnimalStats.generate(for: fighter1, environment: statEnv)
            let stats2 = AnimalStats.generate(for: fighter2, environment: statEnv)
            let score1 = Double(stats1.speed + stats1.power + stats1.agility + stats1.defense)
            let score2 = Double(stats2.speed + stats2.power + stats2.agility + stats2.defense)
            let f1Wins = score1 != score2 ? score1 > score2
                : fighter1.size != fighter2.size ? fighter1.size > fighter2.size
                : fighter1.id < fighter2.id
            winnerAnimal = f1Wins ? fighter1 : fighter2
            loserAnimal = f1Wins ? fighter2 : fighter1
            let (w, l) = f1Wins ? (score1, score2) : (score2, score1)
            dominance = (w + l) > 0 ? w / (w + l) : 0.55
        }

        // Generic, name-respectful copy (no "The", no "creature/heavyweight"
        // assumptions) so it reads fine for ANY fighter — animal, person, or
        // anything a kid types.
        let narration = "\(winnerAnimal.name) came out on top after a hard-fought battle! \(loserAnimal.name) gave it everything, but \(winnerAnimal.name) had just enough to take the win."

        // A real, hand-checked fact about the winner when we have one.
        let funFact: String
        if let fact = AnimalFacts.facts(for: winnerAnimal.id) {
            funFact = "\(winnerAnimal.name) fact: \(fact.coolFact)"
        } else {
            funFact = "When two go head-to-head, it often comes down to who keeps their cool under pressure — and today, that was \(winnerAnimal.name)."
        }

        var result = BattleResult(
            winner: winnerAnimal.id,
            narration: narration,
            funFact: funFact,
            winnerHealthPercent: min(90, 55 + Int(dominance * 35)),
            loserHealthPercent: max(5, Int((1 - dominance) * 30))
        )
        result.isOfflineFallback = markAsOffline
        return result
    }
}

// MARK: - BattleError

enum BattleError: LocalizedError, Equatable {
    case serverError
    case networkUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .serverError: return "The battle server is resting. Try again!"
        case .networkUnavailable: return "No internet! The animals need WiFi to fight."
        case .rateLimited: return "Wow, you've been battling a lot! The arena needs a 15-minute break. Come back soon!"
        }
    }
}
