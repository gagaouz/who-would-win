import Foundation

/// Offline melee narration generator. The backend produces cinematic prose
/// when reachable; when the device falls back to local resolution we still
/// want kid-friendly EPIC narration, not a one-line canned template. This
/// composes a multi-sentence story from a pool of action beats, picking
/// different beats each call so repeated melees don't read identically.
enum MeleeFallbackStory {

    // ─── Beat pools (each line is a complete sentence) ─────────────────────

    // Tone matches the server's story rules: an exciting contest, never an
    // injury, and names used as given (no "The Biden").
    private static let openers: [(_ first: String) -> String] = [
        { "The arena trembles as \($0) bursts forward with a thunderous roar!" },
        { "The whistle blows and \($0) charges in like a rocket, ready for action!" },
        { "Dust kicks up in a swirling cloud as \($0) leads the charge!" },
        { "A mighty battle cry echoes through the arena as \($0) springs into action!" },
        { "The crowd goes WILD as \($0) races onto the field, the ground shaking with every step!" },
    ]

    private static let signatureMoves: [(_ winner: String) -> String] = [
        { "\($0) lands a huge hip-check that sends the other side tumbling across the arena!" },
        { "With a lightning-fast swoop, \($0) dodges, spins and knocks the other team off balance!" },
        { "\($0) pulls off a bone-rattling tackle that lifts an opponent clean off the ground!" },
        { "\($0) plants its feet and pushes the whole other side back, step by step!" },
        { "\($0) pivots and sweeps the field with one mighty move that leaves the other team scrambling!" },
    ]

    // Separate solo/team pools so a lone winner never gets plural grammar
    // ("Lion stand tall as the undisputed champions").
    private static let teamClosers: [(_ winningSide: String) -> String] = [
        { "When the dust finally settles, \($0) stand tall as the champions!" },
        { "The crowd erupts in cheers as \($0) raise their heads in victory — the arena belongs to them!" },
        { "\($0) hold the field in triumph while the other side backs away!" },
        { "\($0) claim the win in a swirl of dust and glory — what a battle!" },
    ]

    private static let soloClosers: [(_ winner: String) -> String] = [
        { "When the dust finally settles, \($0) stands tall as the champion!" },
        { "The crowd erupts in cheers as \($0) lifts its head in victory — the arena belongs to it!" },
        { "\($0) holds the field in triumph while the other side backs away!" },
        { "\($0) claims the win in a swirl of dust and glory — what a battle!" },
    ]

    // ─── Public API ────────────────────────────────────────────────────────

    static func narrate(winners: [Animal], losers: [Animal], mvp: Animal) -> String {
        // A 3-beat sequence (opener · signature move · close) so the result
        // panel stays scannable.
        let winnerNames = list(winners.map { $0.name })
        let opener = openers.randomElement()!(mvp.name)
        let move   = signatureMoves.randomElement()!(mvp.name)
        let close  = winners.count > 1
            ? teamClosers.randomElement()!(winnerNames)
            : soloClosers.randomElement()!(mvp.name)
        return [opener, move, close].joined(separator: " ")
    }

    /// A real, hand-checked fact about a winner when we have one; otherwise a
    /// line that makes no factual claim.
    static func funFact(winners: [Animal], losers: [Animal]) -> String {
        for animal in winners {
            if let fact = AnimalFacts.facts(for: animal.id) {
                return "\(animal.name) fact: \(fact.coolFact)"
            }
        }
        let winKind = winners.first?.name ?? "The winners"
        return "Team battles are about more than size: speed, smarts and working together all matter, and today \(winKind) had the winning mix!"
    }

    // Joins a list with commas + "and" for the last item.
    // ["Lion","Tiger","Wolf"] → "Lion, Tiger, and Wolf"
    private static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head), and \(items.last!)"
        }
    }
}
