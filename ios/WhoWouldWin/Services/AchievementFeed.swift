import Foundation
import Combine

/// Bridges the non-observable AchievementTracker to SwiftUI so newly-earned
/// badges can be celebrated WHERE they're earned (the battle result screen)
/// instead of only living silently in Game Center. `markEarned` pushes here;
/// the result view pops one and shows a "NEW BADGE!" toast.
///
/// Deliberately NOT a `@MainActor` class: `markEarned` runs in a nonisolated
/// context, so a main-actor `shared` would warn (and error under Swift 6).
/// Instead we keep the type nonisolated and route the `@Published` mutation
/// onto the main queue ourselves.
final class AchievementFeed: ObservableObject {
    static let shared = AchievementFeed()

    /// FIFO queue of human-readable names of just-unlocked badges.
    @Published private(set) var queue: [String] = []

    private init() {}

    /// Called from AchievementTracker.markEarned (any thread). The append is
    /// always dispatched to main so `@Published`/`objectWillChange` fire on the
    /// UI thread, and the result view's `onChange(of: queue)` picks it up.
    func push(rawId: String) {
        let name = Self.displayName(fromRawId: rawId)
        DispatchQueue.main.async { self.queue.append(name) }
    }

    /// Pop the next unlocked-badge name to display, if any. Called from SwiftUI
    /// (main thread).
    func popNext() -> String? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    /// Drop any queued badges (e.g. ones earned outside a battle) so a surface
    /// only ever shows badges it is responsible for. Call on the main thread.
    func clear() {
        if !queue.isEmpty { queue.removeAll() }
    }

    /// "com.whowouldin.achievement.firstFight" → "First Fight".
    static func displayName(fromRawId raw: String) -> String {
        let last = raw.split(separator: ".").last.map(String.init) ?? raw
        var words = ""
        for ch in last {
            if ch.isUppercase && !words.isEmpty { words.append(" ") }
            words.append(ch)
        }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
