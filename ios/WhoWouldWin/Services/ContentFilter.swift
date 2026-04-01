import Foundation

/// Screens custom fighter names for content that is inappropriate for a kids app.
/// Uses whole-word matching only (split on whitespace) to avoid false positives
/// like blocking "bass" because it contains "ass".
enum ContentFilter {

    private static let blockedWords: Set<String> = [
        // Sexual anatomy
        "penis", "vagina", "vulva", "anus", "anal", "rectum",
        "testicle", "testicles", "scrotum", "breasts", "nipple", "nipples",
        "clitoris", "genitals", "genitalia", "foreskin",
        // Sexual profanity
        "fuck", "shit", "bitch", "cunt", "ass", "asshole", "cock", "dick", "pussy",
        "whore", "slut", "cum", "semen", "sperm", "tits", "boobs", "butthole", "twat",
        "wank", "wanker", "jizz", "boner",
        // NSFW concepts
        "porn", "porno", "naked", "nude", "erection", "dildo", "vibrator", "condom",
        "sexting", "blowjob", "handjob", "rimjob", "threesome", "orgasm",
        "masturbate", "masturbation", "intercourse", "prostitute", "prostitution",
        "stripper", "brothel",
        // Mild profanity (kids app)
        "bastard", "piss", "prick", "crap", "damn", "hell", "damnit", "goddamn",
        "bullshit", "horseshit", "jackass", "dumbass", "dipshit", "dickhead",
        // Slurs
        "nigger", "nigga", "faggot", "fag", "kike", "spic", "chink", "wetback",
        "tranny", "coon", "gook", "retard", "cracker", "dyke", "beaner",
        "towelhead", "raghead", "sandnigger", "honky",
        // Drugs
        "cocaine", "heroin", "meth", "methamphetamine", "marijuana", "weed", "crack",
        "fentanyl", "mdma", "ecstasy", "lsd", "opioid", "opioids", "ketamine",
        "shrooms", "mushrooms", "peyote", "mescaline", "amphetamine", "amphetamines",
        "xanax", "adderall", "morphine", "oxycodone", "oxycontin",
        // Violence / harm
        "rape", "murder", "kill", "suicide", "terrorist", "terrorism", "genocide",
        "torture", "massacre", "stabbing", "shooting", "assault", "molest",
        "molestation", "pedophile", "pedophilia", "incest", "necrophilia", "bestiality",
    ]

    /// Returns `true` if the text is safe to use as a custom fighter name.
    static func isAppropriate(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return !words.contains { blockedWords.contains($0) }
    }
}
