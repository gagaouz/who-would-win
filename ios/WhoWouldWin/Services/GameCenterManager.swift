//
//  GameCenterManager.swift
//  WhoWouldWin
//
//  Game Center integration for Animal vs Animal.
//  Handles authentication, achievement reporting, and presenting
//  the Game Center UI (achievements & leaderboards).
//

import Foundation
import GameKit
import SwiftUI

final class GameCenterManager: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?

    private var reportedThisSession: Set<String> = []

    private override init() { super.init() }

    // MARK: - GKGameCenterControllerDelegate
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }

    // MARK: - Leaderboard IDs
    // All 4 leaderboards are cumulative/best-score (not recurring).
    enum LeaderboardID: String, CaseIterable {
        case totalBattles       = "com.whowouldin.leaderboard.totalBattles"
        case tournamentsWon     = "com.whowouldin.leaderboard.tournamentsWon"
        case longestStreak      = "com.whowouldin.leaderboard.longestStreak"
        case peakCoins          = "com.whowouldin.leaderboard.peakCoins"
    }

    // MARK: - Authentication

    /// Call on app launch. Presents Game Center login if iOS hands us a VC for it.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let vc = viewController {
                    print("[GameCenter] iOS handed us the sign-in VC — presenting.")
                    self?.presentOnTopmost(vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    print("[GameCenter] Authenticated as \(GKLocalPlayer.local.displayName)")
                    self?.isAuthenticated = true
                    self?.localPlayer = GKLocalPlayer.local
                    self?.loadEarnedAchievements()
                    self?.submitCurrentStatsToLeaderboards()
                } else {
                    self?.isAuthenticated = false
                    self?.localPlayer = nil
                    if let error = error {
                        print("[GameCenter] Auth failed: \(error.localizedDescription)")
                    } else {
                        print("[GameCenter] Not authenticated, no VC, no error — user declined or rate-limited.")
                    }
                }
            }
        }
    }

    /// Walks up the presented-view-controller chain so we present on the true top
    /// VC — otherwise a modal already on screen silently swallows the sign-in sheet.
    private func presentOnTopmost(_ vc: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController
        else {
            print("[GameCenter] Couldn't find a window to present on — will retry in 0.5s.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.presentOnTopmost(vc)
            }
            return
        }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }
        let vcName = String(describing: type(of: vc))
        print("[GameCenter] Presenting \(vcName) on \(String(describing: type(of: top)))")
        top.present(vc, animated: true) {
            print("[GameCenter] \(vcName) present() completed.")
        }
    }

    // MARK: - Achievement Reporting

    /// Reports an achievement as 100% complete. Idempotent — skips if already reported this session.
    func reportAchievement(_ identifier: String) {
        guard isAuthenticated else { return }
        guard !reportedThisSession.contains(identifier) else { return }

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { [weak self] error in
            if let error = error {
                print("[GameCenter] Failed to report \(identifier): \(error.localizedDescription)")
            } else {
                self?.reportedThisSession.insert(identifier)
            }
        }
    }

    /// Reports an achievement with a specific progress percentage (0-100). For progressive achievements.
    func reportProgress(_ identifier: String, percentComplete: Double) {
        guard isAuthenticated else { return }

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = min(100, max(0, percentComplete))
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("[GameCenter] Failed to report progress for \(identifier): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Leaderboard Reporting

    /// Submits a score to a leaderboard. No-op if not authenticated.
    /// For cumulative/best-score leaderboards (all 4 of ours) Game Center keeps the max.
    func reportScore(_ leaderboard: LeaderboardID, value: Int) {
        guard isAuthenticated else { return }
        guard value > 0 else { return }

        GKLeaderboard.submitScore(
            value,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [leaderboard.rawValue]
        ) { error in
            if let error = error {
                print("[GameCenter] Failed to submit score to \(leaderboard.rawValue): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show Game Center UI
    //
    // IMPORTANT: `GKGameCenterViewController` is a full-screen UIKit VC.
    // Two gotchas:
    //   1. Wrapping it inside a SwiftUI `.sheet` via
    //      `UIViewControllerRepresentable` renders a blank grey screen —
    //      it must be `present()`ed directly from a UIKit VC.
    //   2. If we present while another SwiftUI sheet (e.g. Settings) is
    //      still dismissing, UIKit silently no-ops because the sheet's
    //      hosting controller is still `.presentedViewController`.
    //
    // Solution: let SwiftUI stash a "pending action" here, dismiss its
    // own sheet, then in that sheet's `onDismiss` call `flushPending()`
    // to present on the now-uncovered root VC.

    enum PendingAction {
        case achievements
        case leaderboards
        case dashboard
    }

    /// Set by a view that's about to dismiss a sheet and wants GC to appear afterwards.
    var pendingAction: PendingAction?

    /// Call from `.sheet(onDismiss:)` — presents whatever was queued.
    func flushPending() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .achievements: presentAchievements()
        case .leaderboards: presentLeaderboards()
        case .dashboard:    presentDashboard()
        }
    }

    func presentAchievements() { presentGameCenter(state: .achievements) }
    func presentLeaderboards() { presentGameCenter(state: .leaderboards) }
    func presentDashboard()    { presentGameCenter(state: .dashboard) }

    private func presentGameCenter(state: GKGameCenterViewControllerState) {
        let vc = GKGameCenterViewController(state: state)
        vc.gameCenterDelegate = self
        presentOnTopmost(vc)
    }

    // MARK: - Current-Stats Resync

    /// On auth success, resubmit the player's current stats so their
    /// persisted progress (battles, streak, coins, tournaments) is on the
    /// leaderboards even if this is the first install of a leaderboard build
    /// or they signed into GC for the first time.
    private func submitCurrentStatsToLeaderboards() {
        DispatchQueue.main.async {
            let settings = UserSettings.shared
            let defaults = UserDefaults.standard
            let tournamentsCompleted = defaults.integer(forKey: "achievement.tournamentsCompleted")
            let balance = defaults.integer(forKey: "coin.balance")

            self.reportScore(.totalBattles,  value: settings.totalBattleCount)
            self.reportScore(.longestStreak, value: settings.longestStreak)
            self.reportScore(.tournamentsWon, value: tournamentsCompleted)
            self.reportScore(.peakCoins,     value: balance)
        }
    }

    // MARK: - Load Earned Achievements

    private func loadEarnedAchievements() {
        GKAchievement.loadAchievements { achievements, error in
            guard let achievements = achievements else { return }
            let earned = achievements.filter { $0.percentComplete >= 100 }.map { $0.identifier }.filter { !$0.isEmpty }
            // Sync earned achievements to local storage so AchievementTracker knows what's already done
            DispatchQueue.main.async {
                let defaults = UserDefaults.standard
                var local = Set(defaults.stringArray(forKey: "achievement.earned") ?? [])
                local.formUnion(earned)
                defaults.set(Array(local), forKey: "achievement.earned")
            }
        }
    }
}

// NOTE: The old `GameCenterView: UIViewControllerRepresentable` wrapper was
// removed — wrapping `GKGameCenterViewController` inside a SwiftUI sheet
// results in a blank grey screen because GC's full-screen VC cannot lay
// itself out inside a UIHostingController. Use
// `GameCenterManager.shared.presentAchievements()` / `.presentLeaderboards()`
// which calls UIKit's `present` on the topmost VC instead.
