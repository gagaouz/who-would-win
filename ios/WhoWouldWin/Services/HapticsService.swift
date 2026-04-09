import UIKit

/// Thin wrapper around UIKit haptics. All calls are no-ops when
/// the user has disabled haptics in Settings.
final class HapticsService {
    static let shared = HapticsService()
    private init() {}

    /// Light tap — button presses, card selections.
    func tap() {
        fire(UIImpactFeedbackGenerator(style: .light))
    }

    /// Medium impact — FIGHT! button, confirming selections.
    func medium() {
        fire(UIImpactFeedbackGenerator(style: .medium))
    }

    /// Heavy impact — battle clash moment.
    func heavy() {
        fire(UIImpactFeedbackGenerator(style: .heavy))
    }

    /// Success notification — winner reveal.
    func success() {
        guard UserSettings.shared.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    /// Error notification — draw or defeat.
    func warning() {
        guard UserSettings.shared.hapticsEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.warning)
    }

    private func fire(_ gen: UIImpactFeedbackGenerator) {
        guard UserSettings.shared.hapticsEnabled else { return }
        gen.prepare()
        gen.impactOccurred()
    }
}
