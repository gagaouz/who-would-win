import Foundation

// ---------------------------------------------------------------------------
// CloudSyncService
// ---------------------------------------------------------------------------
// Syncs important UserDefaults state to iCloud Key-Value Store so that
// progression, purchases, and achievements survive app deletion.
//
// Merge strategies (conflict resolution when cloud != local):
//   - Int keys  : MAX   -- keep the higher value (progress only goes up)
//   - Bool keys : TRUE-WINS -- once unlocked, never re-lock
//   - Array keys: UNION -- combine both sets, deduplicated
// ---------------------------------------------------------------------------

final class CloudSyncService {

    static let shared = CloudSyncService()

    // MARK: - Notifications

    /// Posted after cloud data has been restored into UserDefaults.
    /// UI should observe this to refresh any displayed values.
    static let didRestoreNotification = Notification.Name("CloudSyncDidRestore")

    // MARK: - Key Definitions

    /// Int keys use MAX merge -- whichever side is higher wins.
    private let intKeys: [String] = [
        "stat.battles",
        "stat.streak",
        "stat.longestStreak",
        "coin.balance",
        "achievement.totalCoinsSpent",
        "achievement.tournamentsCompleted"
    ]

    /// Double keys use MAX merge (timestamps, etc.).
    private let doubleKeys: [String] = [
        "stat.lastBattleDate"
    ]

    /// Bool keys use TRUE-wins merge -- once true, stays true forever.
    private let boolKeys: [String] = [
        "coin.welcomed",
        "coin.firstCustomAwarded",
        "coin.tournamentSeedAwarded",
        "iap.noads",
        "iap.sub",
        "iap.fantasy",
        "iap.prehistoric",
        "iap.mythic",
        "iap.olympus",
        "iap.environments",
        "pref.tournamentUnlocked"
    ]

    /// Array-of-String keys use UNION merge -- combine both sides, deduplicated.
    private let arrayKeys: [String] = [
        "achievement.environmentsWon",
        "achievement.customCreaturesUsed",
        "achievement.categoriesBattled",
        "achievement.earned",
        "achievement.uniqueAnimalsUsed"
    ]

    // MARK: - Debounce State

    /// Minimum interval between cloud writes to stay well within the
    /// iCloud KV store rate limit (~10-12 writes/min recommended by Apple).
    private let debounceInterval: TimeInterval = 5.0
    private var lastSyncTime: Date = .distantPast
    private var pendingWorkItem: DispatchWorkItem?

    // MARK: - Convenience Accessors

    private var defaults: UserDefaults { .standard }
    private var cloud: NSUbiquitousKeyValueStore { .default }

    // MARK: - Init

    private init() {
        // Listen for external changes pushed from another device or
        // after an initial iCloud download completes.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        // Kick off an initial sync pull so we pick up anything that
        // arrived while the app was not running.
        cloud.synchronize()
    }

    // MARK: - Public API

    /// Writes all tracked UserDefaults keys to iCloud KV store.
    /// Call this when you know state just changed and want it persisted
    /// to the cloud immediately (bypasses debounce).
    func syncToCloud() {
        // -- Ints --
        for key in intKeys {
            cloud.set(defaults.integer(forKey: key), forKey: key)
        }

        // -- Doubles --
        for key in doubleKeys {
            cloud.set(defaults.double(forKey: key), forKey: key)
        }

        // -- Bools --
        for key in boolKeys {
            cloud.set(defaults.bool(forKey: key), forKey: key)
        }

        // -- String arrays --
        for key in arrayKeys {
            let local = defaults.stringArray(forKey: key) ?? []
            cloud.set(local, forKey: key)
        }

        cloud.synchronize()
        lastSyncTime = Date()
    }

    /// Reads from iCloud KV store and merges into UserDefaults using the
    /// appropriate strategy per key type.
    ///
    /// After merging, posts `CloudSyncService.didRestoreNotification` so
    /// any visible UI can refresh itself.
    func restoreFromCloud() {
        cloud.synchronize()

        // -- Int keys: MAX merge --
        // Progress only moves forward. If the cloud has a higher battle
        // count (e.g. from a previous install), keep that number.
        for key in intKeys {
            let local = defaults.integer(forKey: key)
            let remote = Int(cloud.longLong(forKey: key))
            let merged = max(local, remote)
            defaults.set(merged, forKey: key)
        }

        // -- Double keys: MAX merge --
        // Timestamps: the most-recent date wins.
        for key in doubleKeys {
            let local = defaults.double(forKey: key)
            let remote = cloud.double(forKey: key)
            let merged = max(local, remote)
            defaults.set(merged, forKey: key)
        }

        // -- Bool keys: TRUE-wins merge --
        // Once something is unlocked or purchased, it should never
        // revert to locked. If either local OR cloud is true, the
        // merged result is true.
        for key in boolKeys {
            let local = defaults.bool(forKey: key)
            let remote = cloud.bool(forKey: key)
            let merged = local || remote
            defaults.set(merged, forKey: key)
        }

        // -- Array keys: UNION merge --
        // Combine achievements/collections from both sides so nothing
        // is ever lost. Deduplicate by converting through a Set.
        for key in arrayKeys {
            let local = defaults.stringArray(forKey: key) ?? []
            let remote = (cloud.array(forKey: key) as? [String]) ?? []
            let merged = Array(Set(local).union(Set(remote)))
            defaults.set(merged, forKey: key)
        }

        // Write the merged values back to iCloud as well so both sides
        // converge to the same state.
        syncToCloud()

        NotificationCenter.default.post(
            name: CloudSyncService.didRestoreNotification,
            object: nil
        )
    }

    /// Debounced sync -- call this after any state change.
    ///
    /// Waits up to 5 seconds before actually writing. If another call
    /// arrives within that window, the timer resets. This prevents
    /// hammering iCloud KV store during rapid-fire battles.
    func autoSync() {
        // Cancel any pending write.
        pendingWorkItem?.cancel()

        let elapsed = Date().timeIntervalSince(lastSyncTime)

        if elapsed >= debounceInterval {
            // Enough time has passed -- write immediately.
            syncToCloud()
        } else {
            // Schedule a write for when the debounce window expires.
            let delay = debounceInterval - elapsed
            let work = DispatchWorkItem { [weak self] in
                self?.syncToCloud()
            }
            pendingWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    // MARK: - iCloud Change Observer

    /// Called when another device (or the initial iCloud download) pushes
    /// new values into the KV store.
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        // The reason code tells us why the store changed.
        // NSUbiquitousKeyValueStoreServerChange (= 1) is the most common
        // case -- another device wrote new data.
        // We restore on any change reason to be safe.
        restoreFromCloud()
    }
}
