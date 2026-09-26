import Foundation

enum AppConfig {
    /// UI fixtures require an explicit flag and cannot be enabled in Release.
    /// Merely running unit tests must not change resolver behavior.
    static var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--uitesting")
            || ProcessInfo.processInfo.environment["AVA_UI_TESTING"] == "1"
        #else
        return false
        #endif
    }

    static var fixtureScenario: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["AVA_FIXTURE_SCENARIO"] ?? "battle-success"
        #else
        return ""
        #endif
    }

    static var fixtureScreen: String? {
        #if DEBUG
        guard isUITesting else { return nil }
        return ProcessInfo.processInfo.environment["AVA_FIXTURE_SCREEN"]
        #else
        return nil
        #endif
    }

    static var isIsolatedTestBuild: Bool {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "AVAIsolatedTestBuild") as? String == "YES"
        #else
        return false
        #endif
    }

    /// Unit-test hosts also launch the App. Guard SDKs/cloud APIs as well as HTTP.
    static var externalServicesEnabled: Bool {
        #if DEBUG
        return !isUITesting && !isIsolatedTestBuild
            && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
            && ProcessInfo.processInfo.environment["AVA_BLOCK_EXTERNAL_SERVICES"] != "1"
        #else
        return true
        #endif
    }

    static var backendBaseURL: String {
        #if DEBUG
        if !externalServicesEnabled { return "http://localhost:1" }
        #endif
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AVAAPIBaseURL") as? String,
              let url = URL(string: value),
              let host = url.host,
              !host.isEmpty,
              url.scheme == "https" || (url.scheme == "http" && host == "localhost") else {
            // Fail closed if a build configuration was omitted or malformed.
            return "http://localhost:1"
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// MetricKit payloads stay on-device unless deliberately enabled/disclosed.
    static let diagnosticsEnabled = false
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6761319389")!

    /// Run before any shared preference-backed service initializes. Only the
    /// isolated Testing bundle may reset its own fixture data.
    static func prepareTestRuntime() {
        #if DEBUG
        guard !externalServicesEnabled else { return }
        URLProtocol.registerClass(TestNetworkBlocker.self)
        guard isUITesting, isIsolatedTestBuild,
              ProcessInfo.processInfo.arguments.contains("--reset-test-data"),
              let identifier = Bundle.main.bundleIdentifier,
              identifier.hasSuffix(".uitesting") else { return }
        UserDefaults.standard.removePersistentDomain(forName: identifier)
        UserDefaults.standard.register(defaults: [
            "onboard.seenFirstBattle": true,
            "paywall.shownOnce": true,
            "pref.sound": false,
            "pref.narration": false,
            "pref.haptics": false,
            "pref.voicePromptSeen": true,
            "parental.dailyReminder": false
        ])
        #endif
    }
}

#if DEBUG
/// Defense in depth. Service fixtures are explicit; stray HTTP fails locally,
/// including custom image downloads. Release binaries do not contain this class.
private final class TestNetworkBlocker: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        !AppConfig.externalServicesEnabled
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
#endif

#if DEBUG
/// Runs only for an explicitly marked synthetic save on a disposable QA device.
/// The upgrade harness also compiles this observer with the archived 1.1.7 app.
enum UpgradeFixtureAudit {
    @MainActor
    static func captureIfRequested() {
        let ud = UserDefaults.standard
        guard ProcessInfo.processInfo.environment["AVA_CAPTURE_UPGRADE_STATE"] == "1",
              Bundle.main.bundleIdentifier?.hasSuffix(".uitesting") == true,
              ud.string(forKey: "qa.upgradeFixture") == "synthetic-1.1.7" else { return }
        do {
            let settings = UserSettings.shared
            let tournament = TournamentManager.shared.activeTournament
            var state: [String: Any] = [
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                "balance": CoinStore.shared.balance,
                "battleCount": settings.totalBattleCount,
                "streak": settings.currentStreak,
                "longestStreak": settings.longestStreak,
                "predictionsTotal": settings.predictionsTotal,
                "predictionsCorrect": settings.predictionsCorrect,
                "wins": settings.animalWins,
                "collected": StickerCollection.shared.collected.sorted(),
                "earned": AchievementTracker.shared.earnedIDs.sorted(),
                "fantasyUnlocked": settings.fantasyUnlocked,
                "meleeUnlocked": settings.meleeUnlocked,
                "tournamentUnlocked": settings.tournamentUnlocked,
                "wageringEnabled": settings.wageringEnabled,
                "pinSet": ParentalPIN.isPINSet,
                "syntheticPinVerifies": ParentalPIN.verify("2479"),
                "hasResumableTournament": TournamentManager.shared.hasResumableTournament,
                "processedTransactions": ud.stringArray(forKey: "iap.processedConsumableTxIDs") ?? []
            ]
            if let tournament {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                state["tournament"] = try JSONSerialization.jsonObject(with: encoder.encode(tournament))
            }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys])
                .write(to: documents.appendingPathComponent("upgrade-state.json"), options: .atomic)
            let preferences = ud.persistentDomain(forName: Bundle.main.bundleIdentifier!) ?? [:]
            try PropertyListSerialization.data(fromPropertyList: preferences, format: .xml, options: 0)
                .write(to: documents.appendingPathComponent("upgrade-preferences.plist"), options: .atomic)
        } catch {
            assertionFailure("Synthetic upgrade state capture failed: \(error)")
        }
    }
}
#endif
