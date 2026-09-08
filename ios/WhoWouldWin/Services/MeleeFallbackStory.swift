import Foundation

/// Offline melee narration generator. The backend produces cinematic prose
/// when reachable; when the device falls back to local resolution we still
/// want kid-friendly EPIC narration, not a one-line canned template. This
/// composes a multi-sentence story from a pool of action beats, picking
/// different beats each call so repeated melees don't read identically.
enum MeleeFallbackStory {

    // ─── Beat pools (each line is a complete sentence) ─────────────────────

    private static let openers: [(_ first: String) -> String] = [
        { "The arena trembles as \($0) explodes forward with a thunderous roar that shakes the dust off the walls!" },
        { "The whistle blows and \($0) charges in like a missile, claws bared and ready to unleash chaos!" },
        { "Dust kicks up in a swirling cloud as \($0) leads the charge, eyes locked on the enemy line!" },
        { "A bone-chilling battle cry splits the air — \($0) is the first to spring into action!" },
        { "The crowd goes WILD as \($0) bursts onto the battlefield, the ground shaking with every step!" },
    ]

    private static let teamworkBeats: [(_ teammates: String) -> String] = [
        { "\($0) move like a coordinated pack, cutting off escape routes and pressing the advantage from every angle." },
        { "\($0) work the flanks with sharp, snapping attacks that keep the enemy from regrouping." },
        { "Side by side, \($0) double-team their opponents — one distracts, the other strikes." },
        { "\($0) hunt as a unit, circling and feinting until the enemy makes one fatal mistake." },
        { "\($0) press forward shoulder-to-shoulder, an unstoppable wave of teeth, claws, and fury." },
    ]

    private static let signatureMoves: [(_ winner: String) -> String] = [
        { "\($0) unleashes a devastating hip-check that sends the other side crashing across the arena floor!" },
        { "With a swooping strike, \($0) rakes the enemy with claws that flash like curved blades!" },
        { "\($0) lands a bone-shaking tackle that lifts its opponent clean off the ground!" },
        { "A jaw-snapping bite from \($0) connects with thunderous force — the entire arena hears the impact!" },
        { "\($0) pivots and delivers a wrecking-ball tail swipe that ends the fight in one heartbeat!" },
    ]

    // Separate solo/team pools so a lone winner never gets plural grammar
    // ("Lion stand tall as the undisputed champions").
    private static let teamClosers: [(_ winningSide: String) -> String] = [
        { "When the dust finally settles, \($0) stand tall as the undisputed champions, chests heaving and eyes blazing!" },
        { "The crowd erupts in thunderous cheers as \($0) raise their heads in victory — the arena belongs to them!" },
        { "\($0) hold the field, triumphant, while the other side limps away defeated!" },
        { "Roaring to the sky, \($0) claim victory — there's a new top of the food chain today!" },
        { "\($0) stand victorious in a swirl of dust and glory — what a battle!" },
    ]

    private static let soloClosers: [(_ winner: String) -> String] = [
        { "When the dust finally settles, \($0) stands tall as the undisputed champion, chest heaving and eyes blazing!" },
        { "The crowd erupts in thunderous cheers as \($0) raises its head in victory — the arena belongs to it!" },
        { "\($0) holds the field, triumphant, while the other side limps away defeated!" },
        { "Roaring to the sky, \($0) claims victory — there's a new top of the food chain today!" },
        { "\($0) stands victorious in a swirl of dust and glory — what a battle!" },
    ]

    private static let funFactTemplates: [(String, String) -> String] = [
        { winnerKind, loserKind in
            "When a \(winnerKind) and a \(loserKind) clash, sheer power and teamwork usually beat individual skill — even an apex predator can be overwhelmed by a coordinated squad!"
        },
        { winnerKind, loserKind in
            "Did you know? In the wild, \(winnerKind)s often hunt as a team — their pack tactics make them MUCH more dangerous than they look on paper, even against a tough \(loserKind)!"
        },
        { winnerKind, loserKind in
            "Power, size, and coordination all decide a melee. The \(winnerKind)'s combination of speed and strength simply outclassed what the \(loserKind) could bring to the fight!"
        },
        { winnerKind, loserKind in
            "Animals fighting in teams use distractions, flanking, and synchronized strikes — that's exactly what let the \(winnerKind) take down the \(loserKind) tonight!"
        },
        { winnerKind, loserKind in
            "Real-world battles aren't just about size — speed, smarts, and friends matter just as much. The \(winnerKind) had all three to spare!"
        },
    ]

    // ─── Public API ────────────────────────────────────────────────────────

    static func narrate(winners: [Animal], losers: [Animal], mvp: Animal) -> String {
        // Trimmed to a 3-beat sequence (opener · signature move · close) so the
        // result panel stays scannable. Five-beat versions felt padded.
        let winnerNames = list(winners.map { $0.name })
        let opener = openers.randomElement()!(mvp.name)
        let move   = signatureMoves.randomElement()!(mvp.name)
        let close  = winners.count > 1
            ? teamClosers.randomElement()!("The \(winnerNames)")
            : soloClosers.randomElement()!("The \(mvp.name)")
        return [opener, move, close].joined(separator: " ")
    }

    static func funFact(winners: [Animal], losers: [Animal]) -> String {
        let winKind = winners.first?.name ?? "winner"
        let loseKind = losers.first?.name ?? "opponent"
        return funFactTemplates.randomElement()!(winKind, loseKind)
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
