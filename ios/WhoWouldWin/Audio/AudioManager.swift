import Foundation

/// AudioManager — audio disabled. All methods are no-ops.
class AudioManager {
    static let shared = AudioManager()
    private init() {}

    func playIntro() {}
    func playClash() {}
    func playVictory() {}
    func playDraw() {}
}
