import Foundation

/// In-memory cheat unlock state.
/// Intentionally NOT persisted — resets to false every time the app is killed.
final class CheatState: ObservableObject {
    static let shared = CheatState()
    @Published var olympusUnlocked = false
    private init() {}
}
