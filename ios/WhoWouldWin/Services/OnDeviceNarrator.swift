import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device battle narration via Apple's Foundation Models framework
/// (`SystemLanguageModel`, iOS 26+). The deterministic `OnDeviceResolver`
/// decides the winner; this type only writes the *story* — preserving the
/// project invariant that the model never decides outcomes.
///
/// Everything is gated behind `@available(iOS 26, *)` and a runtime
/// availability check, so on older OSes / ineligible devices the app simply
/// falls back to the existing Railway + Claude path. Default-OFF behind a
/// settings flag — this is a cost/quality experiment, not yet the shipping
/// narrator.
///
/// Why this matters: narration is the app's #1 operating cost (per-battle
/// Claude tokens via the backend) and its #1 fragility point (timeouts/rate
/// limits force the canned local fallback). On-device narration is instant,
/// free, and works fully offline.
enum OnDeviceNarratorAvailability: Equatable {
    case available
    case unavailable(String)   // human-readable reason for the lab UI

    var isAvailable: Bool { if case .available = self { return true } else { return false } }
    var reason: String? { if case .unavailable(let r) = self { return r } else { return nil } }
}

#if canImport(FoundationModels)

@available(iOS 26.0, macOS 26.0, *)
final class OnDeviceNarrator: Sendable {   // stateless singleton — safe to touch from any actor

    static let shared = OnDeviceNarrator()
    private init() {}

    /// CRITICAL: the default guardrails flag animal *combat* as "unsafe content"
    /// and block the large majority of battle prompts (verified — only ~1 in 4
    /// fights got through with `.default`). Since this entire app is animal
    /// battles, we use `.permissiveContentTransformations`, which still keeps
    /// the model PG (no gore — our prompt enforces that) but allows kid-friendly
    /// fight narration. Without this, on-device narration is a non-starter here.
    private static func makeSession(instructions: String) -> LanguageModelSession {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        return LanguageModelSession(model: model, instructions: instructions)
    }

    // MARK: - Structured output

    /// The model fills this in one shot. Plain `String` fields keep us off the
    /// `@Guide` macro (not relied upon here) — the formatting constraints live
    /// in the instructions/prompt text instead, which is robust across SDK
    /// point releases.
    @Generable
    struct BattleStory {
        @Guide(description: "Exactly 3 cinematic, kid-friendly present-tense sentences telling the battle story. No tier/stat/number jargon.")
        var narration: String
        @Guide(description: "One or two 'whoa, did you know?' sentences about the winner, tied to why it won.")
        var funFact: String
    }

    // MARK: - Availability

    static var availability: OnDeviceNarratorAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable("This device doesn't support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .unavailable("Apple Intelligence is turned off in Settings.")
            case .modelNotReady:
                return .unavailable("The on-device model is still downloading. Try again soon.")
            @unknown default:
                return .unavailable("The on-device model is unavailable.")
            }
        @unknown default:
            return .unavailable("The on-device model is unavailable.")
        }
    }

    /// Warm the model so the first real narration isn't slow. Safe to call early.
    func prewarm() {
        guard Self.availability.isAvailable else { return }
        Self.makeSession(instructions: Self.instructions(forVacuum: false)).prewarm()
    }

    // MARK: - Narration

    /// Narrate a battle whose winner is ALREADY decided.
    /// - Parameters:
    ///   - environmentName: arena name, or `nil` for a true vacuum (no terrain).
    func narrate(winner: Animal,
                 loser: Animal,
                 environmentName: String?,
                 isDraw: Bool = false) async throws -> BattleStory {
        let session = Self.makeSession(instructions: Self.instructions(forVacuum: environmentName == nil))
        let prompt = Self.prompt(winner: winner, loser: loser,
                                 environmentName: environmentName, isDraw: isDraw)
        // Temperature 0.9 mirrors the backend's creative setting for narration.
        let options = GenerationOptions(temperature: 0.9)
        let response = try await session.respond(to: prompt, generating: BattleStory.self, options: options)
        return response.content
    }

    // MARK: - Prompt construction (ported from backend/src/services/claudeService.ts)

    private static func instructions(forVacuum: Bool) -> String {
        // End-beat examples are venue-neutral in vacuum mode so "arena"/"crowd"
        // don't sneak a setting into a no-terrain story.
        let endBeat = forVacuum
            ? "(\"stands tall with a final triumphant roar\", \"lifts its head, victorious\")"
            : "(\"stands roaring over the arena\", \"lifts its head as the crowd erupts\")"

        var s = """
        You are the cinematic narrator for "Who Would Win?", a fun battle game for kids. \
        The WINNER HAS ALREADY BEEN DECIDED by the game's referee. Your ONLY job is to write \
        the battle story explaining why the winner beats the loser. NEVER change, question, or \
        contradict the winner — narrate the outcome you are given.

        Narration rules — write it CINEMATIC, like a kids action-movie trailer:
        - EXACTLY 3 sentences, present tense, every sentence pulses with action.
        - Use punchy verbs (charges, slams, vaults, gores, rips, soars, crashes) and sensory \
        hits (dust kicks up, the ground shakes, a roar splits the air).
        - Open with a dramatic moment, not a bland intro. End on a triumphant beat \(endBeat).
        - Name AT LEAST ONE specific signature move or weapon ("a bone-shattering bite", \
        "a swooping talon strike").
        - Kid-friendly — no gore, no blood, PG impact.
        - FORBIDDEN bland phrases: "ultimately won", "proved too much", "fought bravely", \
        "stood victorious", "couldn't keep up", "no match for".
        - FORBIDDEN system jargon: NEVER mention "tier", "tier gap", "stat", "rating", \
        "power level", or any numeric size/weight category. Describe size and strength with \
        imagery ("massive frame", "thunderous mass"), never numbers or labels.

        Fun-fact rules — a "whoa, did you know?" reveal kids will want to repeat:
        - 1–2 sentences. A surprising biological or mythical detail tied to WHY the winner won.
        - Speak like a kid is reading it. No jargon.
        """
        if forVacuum {
            s += """


            NO ARENA — the fight happens in a featureless neutral void. STRICT:
            - Do NOT mention savanna, ocean, jungle, sky, land, water, or any terrain.
            - Do NOT use habitat descriptors like "ocean giant" or "savanna king" — use the \
            fighter's name.
            - Do NOT treat anyone as "out of their element", "stranded", "beached", or "in its home".
            - Give NEITHER fighter an environmental bonus or penalty — describe only their bodies, \
            weapons, and moves.
            """
        }
        return s
    }

    private static func prompt(winner: Animal, loser: Animal,
                              environmentName: String?, isDraw: Bool) -> String {
        if isDraw {
            let place = environmentName.map { "in the \($0)" } ?? "in a featureless neutral void"
            return "\(winner.name) and \(loser.name) battle to an even draw \(place). " +
                   "Write a 3-sentence story where NEITHER wins, plus a fun fact about both."
        }
        let place = environmentName.map { "in the \($0)" } ?? "in a featureless neutral void"
        return "\(winner.name) defeats \(loser.name) \(place). " +
               "Write the battle story (winner: \(winner.name)) and a fun fact about the \(winner.name)."
    }
}

#endif
