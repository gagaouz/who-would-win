import Foundation

actor BattleService {
    static let shared = BattleService()

    private init() {}

    // MARK: - Network Battle

    func fetchBattleResult(fighter1: Animal, fighter2: Animal) async throws -> BattleResult {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/battle") else {
            throw BattleError.serverError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15   // fail fast; offline fallback kicks in after 15 s
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "fighter1": fighter1.id,
            "fighter2": fighter2.id,
            "fighter1Name": fighter1.name,
            "fighter2Name": fighter2.name
        ]
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

    // MARK: - Offline Fallback

    /// Determines winner based on size with some randomness.
    /// Larger size wins ~70% of matchups, 10% draw chance.
    /// Marks result with isOfflineFallback = true.
    func generateFallbackResult(fighter1: Animal, fighter2: Animal) -> BattleResult {
        let roll = Double.random(in: 0..<1)

        let winner: String
        let winnerAnimal: Animal
        let loserAnimal: Animal

        if roll < 0.10 {
            // 10% draw
            winner = "draw"
            winnerAnimal = fighter1
            loserAnimal = fighter2
        } else if fighter1.size == fighter2.size {
            // Equal size: coin flip for the remaining 90%
            if roll < 0.55 {
                winner = fighter1.id
                winnerAnimal = fighter1
                loserAnimal = fighter2
            } else {
                winner = fighter2.id
                winnerAnimal = fighter2
                loserAnimal = fighter1
            }
        } else {
            // Different sizes: larger wins 70% of the remaining 90%
            let largerAnimal = fighter1.size > fighter2.size ? fighter1 : fighter2
            let smallerAnimal = fighter1.size > fighter2.size ? fighter2 : fighter1
            let largerWinThreshold = 0.10 + 0.90 * 0.70 // 73%
            if roll < largerWinThreshold {
                winner = largerAnimal.id
                winnerAnimal = largerAnimal
                loserAnimal = smallerAnimal
            } else {
                winner = smallerAnimal.id
                winnerAnimal = smallerAnimal
                loserAnimal = largerAnimal
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
        result.isOfflineFallback = true
        return result
    }
}

// MARK: - BattleError

enum BattleError: LocalizedError {
    case serverError
    case networkUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .serverError: return "The battle server is resting. Try again!"
        case .networkUnavailable: return "No internet! The animals need WiFi to fight."
        case .rateLimited: return "Too many battles! Rest the arena for a minute."
        }
    }
}
