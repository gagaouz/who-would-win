import Foundation

/// Screens custom fighter names for content that is inappropriate for a kids app.
/// Uses whole-word matching only (split on whitespace) to avoid false positives
/// like blocking "bass" because it contains "ass".
enum ContentFilter {

    private static let blockedWords: Set<String> = [
        "penis", "vagina", "vulva", "anus", "anal", "rectum",
        "testicle", "testicles", "scrotum", "breasts", "nipple", "nipples",
        "clitoris", "cock", "dick", "pussy", "cunt", "ass", "asshole",
        "fuck", "shit", "bitch", "whore", "slut", "cum", "semen", "sperm",
        "porn", "porno", "naked", "nude", "genitals", "genitalia",
        "erection", "dildo", "vibrator", "condom", "foreskin",
        "butthole", "tits", "boobs", "boner", "jizz", "wank", "wanker", "twat",
    ]

    /// Returns `true` if the text is safe to use as a custom fighter name.
    static func isAppropriate(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return !words.contains { blockedWords.contains($0) }
    }
}
