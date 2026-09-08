import Foundation
import StoreKit
import UIKit

/// Asks for an App Store rating at a genuinely happy moment (just after a win),
/// throttled. Apple itself caps the system prompt to ~3/year, but we also gate
/// it so we only ask a few times, early, when the user is most likely delighted.
/// Previously this only existed in dead legacy code, so the live app never asked.
enum RatingsPrompt {
    private static let ud = UserDefaults.standard
    private static let promptedCountKey = "rating.promptedCount"
    private static let lastBattleKey = "rating.lastPromptBattle"

    /// Call after a WIN. `totalBattles` is the post-increment battle count.
    static func maybeAsk(totalBattles: Int) {
        guard ud.integer(forKey: promptedCountKey) < 3 else { return }
        // Happy, early touchpoints — caught before churn, spaced out.
        guard totalBattles == 5 || totalBattles == 20 || totalBattles == 75 else { return }
        guard ud.integer(forKey: lastBattleKey) != totalBattles else { return }
        ud.set(totalBattles, forKey: lastBattleKey)
        ud.set(ud.integer(forKey: promptedCountKey) + 1, forKey: promptedCountKey)

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
