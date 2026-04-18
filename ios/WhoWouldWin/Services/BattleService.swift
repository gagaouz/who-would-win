import Foundation

actor BattleService {
    static let shared = BattleService()

    private init() {}

    // MARK: - Network Battle

    func fetchBattleResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = true, tournamentContext: String? = nil) async throws -> BattleResult {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle") else {
            throw BattleError.serverError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // 25s gives the Railway backend room for a cold-start (~5–15 s) plus
        // a few seconds of LLM round-trip without prematurely tripping the
        // offline fallback. Anything tighter than this misclassifies legit
        // slow-but-working responses as "offline".
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
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
        request.httpBody = try? JSONEncoder().encode(body)

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
        case 200...299:
            break
        case 429:
            throw BattleError.rateLimited
        default:
            throw BattleError.serverError
        }

        do {
            let result = try JSONDecoder().decode(BattleResult.self, from: data)
            return result
        } catch {
            throw BattleError.serverError
        }
    }

    // MARK: - Quick Battle (lightweight AI)

    /// Calls /api/battle/quick — same AI logic but shorter prompt (~4× fewer tokens).
    /// Used by tournament Quick Mode. Never returns a draw.
    func fetchQuickBattleResult(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = false) async throws -> BattleResult {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle/quick") else {
            throw BattleError.serverError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Quick-mode requests are smaller but still hit the same Railway
        // backend, which can cold-start. 20s absorbs the cold-start without
        // making the user wait through every wait-and-fail cycle.
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "fighter1": fighter1.id,
            "fighter2": fighter2.id,
            "fighter1Name": fighter1.name,
            "fighter2Name": fighter2.name,
        ]
        if arenaEffectsEnabled {
            body["environment"]     = environment.rawValue
            body["environmentName"] = environment.name
        }
        request.httpBody = try? JSONEncoder().encode(body)

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
        case 429: throw BattleError.rateLimited
        default:  throw BattleError.serverError
        }

        do {
            return try JSONDecoder().decode(BattleResult.self, from: data)
        } catch {
            throw BattleError.serverError
        }
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

        if roll < 0.10 {
            // 10% draw
            winner = "draw"
            winnerAnimal = fighter1
            loserAnimal = fighter2
        } else {
            // Higher env-adjusted score wins 70% when different, coin flip when tied
            let totalScore = score1 + score2
            let p1WinChance = totalScore > 0 ? (score1 / totalScore * 0.6 + 0.2) : 0.5  // 0.2–0.8 range
            if roll - 0.10 < (p1WinChance * 0.90) {
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

        let narration: String
        if isDraw {
            narration = "Both the \(fighter1.name) and the \(fighter2.name) fought valiantly in an epic clash! Neither could claim victory — the arena falls silent as both warriors stand their ground."
        } else {
            narration = "The \(winnerAnimal.name) dominated the battle with sheer force and determination! The \(loserAnimal.name) put up a fight, but ultimately had to concede defeat."
        }

        let funFact: String
        if isDraw {
            funFact = "Both the \(fighter1.name) and the \(fighter2.name) are remarkable creatures in their own right — nature truly has no equal here."
        } else {
            funFact = "The \(winnerAnimal.name) is a formidable creature with a size rating of \(winnerAnimal.size) out of 5 — making it a top-tier predator in its environment."
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
