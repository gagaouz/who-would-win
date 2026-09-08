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

    /// Legitimate real animals whose names collide with a blocked whole word
    /// ("sperm" in *sperm whale*, "ass" in *wild ass*). These phrases are scrubbed
    /// out before the word-level block check so a kid can battle a real creature.
    private static let allowedPhrases: [String] = [
        "pygmy sperm whale", "dwarf sperm whale", "sperm whale",
        "african wild ass", "asiatic wild ass", "asian wild ass",
        "indian wild ass", "mongolian wild ass", "somali wild ass",
        "persian wild ass", "tibetan wild ass", "wild ass",
    ]

    /// Returns `true` if the text is safe to use as a custom fighter name.
    static func isAppropriate(_ text: String) -> Bool {
        let normalized = text.precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        guard normalized.count <= 24,
              !normalized.contains("@"),
              !normalized.localizedCaseInsensitiveContains("http://"),
              !normalized.localizedCaseInsensitiveContains("https://"),
              !normalized.localizedCaseInsensitiveContains("www.") else { return false }

        // Phone-like contact details are not creature names.
        let digits = normalized.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
        guard digits.count < 8 else { return false }

        // Remove known-safe animal phrases first (longest matches are listed
        // first so "sperm whale" is consumed before a bare term can match).
        var scrubbed = normalized.lowercased()
        for phrase in allowedPhrases where scrubbed.contains(phrase) {
            scrubbed = scrubbed.replacingOccurrences(of: phrase, with: " ")
        }

        let words = scrubbed.unicodeScalars.reduce(into: "") { result, scalar in
            result.append(CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " ")
        }
        .split(whereSeparator: { $0.isWhitespace })
        .map(String.init)

        if words.contains(where: { blockedWords.contains($0) }) { return false }

        // Catch punctuation-separated spelling such as f.u.c.k.
        var singleLetterRun = ""
        for word in words + [""] {
            if word.count == 1 {
                singleLetterRun += word
            } else {
                if singleLetterRun.count >= 4 && blockedWords.contains(singleLetterRun) { return false }
                singleLetterRun = ""
            }
        }
        return true
    }
}
