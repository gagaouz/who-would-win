import Foundation
import AVFoundation

/// Lightweight sound-effect player. The app previously had NO audio (the old
/// AudioManager was a no-op stub) — a silent kids game feels dead. This plays
/// short bundled effects with near-zero latency by pre-loading a small pool of
/// AVAudioPlayers per clip, and honors the user's Sound toggle.
@MainActor
final class SoundService {
    static let shared = SoundService()

    enum Effect: String, CaseIterable {
        case tap, pop, coin, whoosh, cheer, charge, win, badge
    }

    /// A few players per clip so rapid repeats (tapping the cheer meter) don't
    /// cut each other off.
    private var pools: [Effect: [AVAudioPlayer]] = [:]
    private var cursor: [Effect: Int] = [:]
    private var configured = false

    private init() {}

    /// Call once at launch (e.g. in the App init) to warm the players and set
    /// the audio session to "ambient" so effects mix with other audio and
    /// respect the silent switch.
    func prepare() {
        guard !configured else { return }
        configured = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for fx in Effect.allCases {
            guard let url = Bundle.main.url(forResource: fx.rawValue, withExtension: "wav") else { continue }
            var pool: [AVAudioPlayer] = []
            let copies = (fx == .tap || fx == .pop || fx == .coin) ? 4 : 2   // tappable clips get more
            for _ in 0..<copies {
                if let p = try? AVAudioPlayer(contentsOf: url) { p.prepareToPlay(); pool.append(p) }
            }
            pools[fx] = pool
            cursor[fx] = 0
        }
    }

    func play(_ fx: Effect, volume: Float = 1.0) {
        guard UserSettings.shared.soundEnabled else { return }
        if !configured { prepare() }
        guard let pool = pools[fx], !pool.isEmpty else { return }
        let i = (cursor[fx] ?? 0) % pool.count
        cursor[fx] = i + 1
        let player = pool[i]
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
