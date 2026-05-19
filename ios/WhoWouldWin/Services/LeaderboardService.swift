import Foundation

/// Hall of Fame data: top built-in animals by wins / win rate / popularity.
/// Server-aggregated full-mode battles only.
struct LeaderboardEntry: Codable, Identifiable, Hashable {
    let id: String        // animal id (e.g. "lion")
    let name: String      // display name (e.g. "Lion")
    let wins: Int
    let battles: Int
    let winRate: Double
}

struct Leaderboard: Codable {
    let topByWins: [LeaderboardEntry]
    let topByWinRate: [LeaderboardEntry]
    let topByPopularity: [LeaderboardEntry]
    let totalBattles: Int
    let generatedAt: String

    static let empty = Leaderboard(
        topByWins: [], topByWinRate: [], topByPopularity: [],
        totalBattles: 0, generatedAt: ""
    )
}

/// Fetches /api/leaderboard and caches the result on disk so the Hall of Fame
/// opens instantly + stays usable offline. Background-refreshes if cache > 1h.
@MainActor
final class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()

    @Published private(set) var leaderboard: Leaderboard = .empty
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastFetchError: String? = nil
    @Published private(set) var lastFetchedAt: Date? = nil

    private let cacheKey = "leaderboard.cache.v1"
    private let cacheTimeKey = "leaderboard.cache.time.v1"
    private let staleAfter: TimeInterval = 60 * 60   // 1 hour
    private let ud = UserDefaults.standard
    private var inFlight: Task<Void, Never>? = nil

    private init() {
        loadCached()
    }

    private func loadCached() {
        guard let data = ud.data(forKey: cacheKey) else { return }
        if let decoded = try? JSONDecoder().decode(Leaderboard.self, from: data) {
            self.leaderboard = decoded
            self.lastFetchedAt = ud.object(forKey: cacheTimeKey) as? Date
        }
    }

    private var isCacheStale: Bool {
        guard let t = lastFetchedAt else { return true }
        return Date().timeIntervalSince(t) > staleAfter
    }

    /// Triggers a network refresh. If cached data exists, returns immediately
    /// (the @Published value already reflects the cache) and updates in the
    /// background. Force=true bypasses the freshness check.
    ///
    /// The fetch runs in a detached Task that survives view lifecycle changes —
    /// so swiping back from the Hall of Fame mid-fetch doesn't cancel the
    /// network request and leave the next visit stuck on a stale error.
    func refresh(force: Bool = false) async {
        // Clear stale errors on every entry — even if the guard short-circuits,
        // we don't want a previous failure's "Tap to retry" lingering when the
        // cache is now perfectly valid.
        lastFetchError = nil
        guard force || isCacheStale || leaderboard.totalBattles == 0 else { return }
        // Coalesce concurrent calls — await the existing in-flight Task.
        if let existing = inFlight {
            await existing.value
            return
        }
        isLoading = true
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
        inFlight = task
        await task.value
        inFlight = nil
        isLoading = false
    }

    /// Returns true if the error represents a benign cancellation we should
    /// swallow rather than surface to the user. Covers Swift Concurrency
    /// cancellation, URLError(.cancelled), and the underlying NSURLErrorDomain
    /// code -999 that some CFNetwork paths surface with a different bridged
    /// type — all of which we've seen in the wild.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        // Last-ditch: some bridged errors stringify as "cancelled" without
        // matching either type check above.
        if ns.localizedDescription.range(of: "cancel", options: .caseInsensitive) != nil {
            return true
        }
        return false
    }

    private func performFetch() async {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/leaderboard") else {
            await MainActor.run { self.lastFetchError = "Invalid URL" }
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.cachePolicy = .reloadIgnoringLocalCacheData

        // One retry on transient failure (network glitch, DNS hiccup).
        for attempt in 0..<2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    await MainActor.run { self.lastFetchError = "Server returned an error" }
                    return
                }
                let decoded = try JSONDecoder().decode(Leaderboard.self, from: data)
                await MainActor.run {
                    self.leaderboard = decoded
                    self.lastFetchedAt = Date()
                    self.lastFetchError = nil
                    self.ud.set(data, forKey: self.cacheKey)
                    self.ud.set(Date(), forKey: self.cacheTimeKey)
                }
                return
            } catch {
                // Cancellation is benign — surface nothing to the user.
                if isCancellation(error) {
                    #if DEBUG
                    print("[LeaderboardService] suppressed cancellation: \(error)")
                    #endif
                    return
                }
                // Retry transient network failures once before surfacing.
                if attempt == 0, let urlError = error as? URLError,
                   [.networkConnectionLost, .timedOut, .notConnectedToInternet,
                    .dnsLookupFailed, .cannotConnectToHost].contains(urlError.code) {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
                #if DEBUG
                print("[LeaderboardService] fetch failed: \(error)")
                #endif
                await MainActor.run { self.lastFetchError = error.localizedDescription }
                return
            }
        }
    }
}
