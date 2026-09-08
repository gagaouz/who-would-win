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
        // Tournament context: a short server-trusted string describing the round.
        // When present, the backend skips its result cache so each round gets fresh narration.
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

    /// Offline fallback for melees — sums each team's env-adjusted stat total
    /// and picks the winner with a sharp curve (k=3) like the 1v1 fallback.
    /// MVP is the highest-stat fighter from the winning side.
    func generateMeleeFallback(teamA: [Animal], teamB: [Animal],
                               environment: BattleEnvironment = .grassland,
                               markAsOffline: Bool = true) -> MeleeResult {
        let scoreFor: (Animal) -> Double = { animal in
            let s = AnimalStats.generate(for: animal, environment: environment)
            return Double(s.speed + s.power + s.agility + s.defense)
        }
        // Sum each team's power, then apply mild coordination decay so a 4v1
        // isn't worth a full 4× a single fighter.
        let coordA = pow(0.92, Double(teamA.count - 1))
        let coordB = pow(0.92, Double(teamB.count - 1))
        let powerA = teamA.map(scoreFor).reduce(0, +) * coordA
        let powerB = teamB.map(scoreFor).reduce(0, +) * coordB
        let s1 = pow(max(powerA, 1), 3)
        let s2 = pow(max(powerB, 1), 3)
        let total = s1 + s2
        let pAChance = total > 0 ? s1 / total : 0.5
        let aWins = Double.random(in: 0..<1) < pAChance

        let winnerSide = aWins ? teamA : teamB
        let loserSide  = aWins ? teamB : teamA
        let mvp = winnerSide.max { scoreFor($0) < scoreFor($1) } ?? winnerSide[0]

        let narration = MeleeFallbackStory.narrate(winners: winnerSide, losers: loserSide, mvp: mvp)
        let funFact   = MeleeFallbackStory.funFact(winners: winnerSide, losers: loserSide)

        return MeleeResult(
            winningTeam: aWins ? .A : .B,
            narration: narration,
            funFact: funFact,
            mvp: mvp.id,
            teamAHealth: aWins ? Int.random(in: 65...90) : Int.random(in: 8...25),
            teamBHealth: aWins ? Int.random(in: 8...25) : Int.random(in: 65...90),
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

    /// Determines winner based on size with some randomness.
    /// Larger size wins ~70% of matchups, 10% draw chance.
    ///
    /// `markAsOffline` controls whether the result is flagged with
    /// `isOfflineFallback = true`. Pass `true` only when the device is
    /// genuinely offline (no internet); pass `false` when this is a local
    /// fallback for a server slowdown / 5xx / rate-limit so the user does NOT
    /// see a misleading "⚡ Offline result" badge while they're online.
    func generateFallbackResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, markAsOffline: Bool = true) -> BattleResult {
        let roll = Double.random(in: 0..<1)

        // Compute environment-adjusted total power for each fighter
        let stats1 = AnimalStats.generate(for: fighter1, environment: environment)
        let stats2 = AnimalStats.generate(for: fighter2, environment: environment)
        let score1 = Double(stats1.speed + stats1.power + stats1.agility + stats1.defense)
        let score2 = Double(stats2.speed + stats2.power + stats2.agility + stats2.defense)

        let winner: String
        let winnerAnimal: Animal
        let loserAnimal: Animal

        if roll < 0.05 {
            // 5% draw (small chance — only triggers on truly even matchups; the
            // sharper win-curve below already makes lopsided matches deterministic)
            winner = "draw"
            winnerAnimal = fighter1
            loserAnimal = fighter2
        } else {
            // Sharper win curve: score1^k / (score1^k + score2^k) with k=3.
            // For a 2:1 stat ratio this gives ~89% to the stronger fighter; for
            // a 7:1 ratio (e.g. pteranodon vs army ant) it gives ~99.7%. Avoids
            // the old formula's 80% cap, which let obviously-weaker fighters win
            // ~20% of the time even in absurd mismatches.
            let k: Double = 3.0
            let s1 = pow(max(score1, 1), k)
            let s2 = pow(max(score2, 1), k)
            let total = s1 + s2
            let p1WinChance = total > 0 ? s1 / total : 0.5
            let r = (roll - 0.05) / 0.95     // normalize remaining roll to [0, 1)
            if r < p1WinChance {
                winner = fighter1.id
                winnerAnimal = fighter1
                loserAnimal = fighter2
            } else {
                winner = fighter2.id
                winnerAnimal = fighter2
                loserAnimal = fighter1
            }
        }

        let isDraw = winner == "draw"

        // Generic, name-respectful copy (no "The", no "creature/heavyweight"
        // assumptions) so it reads fine for ANY fighter — animal, person, or
        // anything a kid types. This only ever shows if the cloud AI is
        // unreachable, so it must never embarrass.
        let narration: String
        if isDraw {
            narration = "\(fighter1.name) and \(fighter2.name) went toe-to-toe in an all-out clash — and neither would back down. It's a draw!"
        } else {
            narration = "\(winnerAnimal.name) came out on top after a hard-fought battle! \(loserAnimal.name) gave it everything, but \(winnerAnimal.name) had just enough to take the win."
        }

        let funFact: String
        if isDraw {
            funFact = "A matchup this even is rare — two opponents so closely matched that no one could be crowned!"
        } else {
            funFact = "When two go head-to-head, it often comes down to who keeps their cool under pressure — and today, that was \(winnerAnimal.name)."
        }

        let winnerHealthPercent = isDraw ? 50 : Int.random(in: 55...90)
        let loserHealthPercent = isDraw ? 50 : Int.random(in: 5...25)

        var result = BattleResult(
            winner: winner,
            narration: narration,
            funFact: funFact,
            winnerHealthPercent: winnerHealthPercent,
            loserHealthPercent: loserHealthPercent
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
