import Foundation

// MARK: - Achievement Tracker
// Checks game events against 76 achievement definitions and reports them via Game Center.
// All tracking state persists in UserDefaults and syncs via iCloud.

final class AchievementTracker {
    static let shared = AchievementTracker()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Achievement IDs
    // All IDs use reverse-domain format for Game Center registration.

    enum AchievementID: String, CaseIterable {
        // ── Battle Milestones (9) ──
        case firstFight              = "com.whowouldin.achievement.firstFight"
        case tenBattles              = "com.whowouldin.achievement.tenBattles"
        case fiftyBattles            = "com.whowouldin.achievement.fiftyBattles"
        case hundredBattles          = "com.whowouldin.achievement.hundredBattles"
        case twoFiftyBattles         = "com.whowouldin.achievement.twoFiftyBattles"
        case fiveHundredBattles      = "com.whowouldin.achievement.fiveHundredBattles"
        case thousandBattles         = "com.whowouldin.achievement.thousandBattles"
        case fiveThousandBattles     = "com.whowouldin.achievement.fiveThousandBattles"
        case tenThousandBattles      = "com.whowouldin.achievement.tenThousandBattles"

        // ── Category Mashups (8) ──
        case surfAndTurf             = "com.whowouldin.achievement.surfAndTurf"
        case whenPigsFly             = "com.whowouldin.achievement.whenPigsFly"
        case bugZapper               = "com.whowouldin.achievement.bugZapper"
        case prehistoricShowdown     = "com.whowouldin.achievement.prehistoricShowdown"
        case mythVsMyth              = "com.whowouldin.achievement.mythVsMyth"
        case godFight                = "com.whowouldin.achievement.godFight"
        case fantasyRumble           = "com.whowouldin.achievement.fantasyRumble"
        case categoryCollector       = "com.whowouldin.achievement.categoryCollector"

        // ── Upsets (5) ──
        case davidVsGoliath          = "com.whowouldin.achievement.davidVsGoliath"
        case godSlayer               = "com.whowouldin.achievement.godSlayer"
        case bugSquasher             = "com.whowouldin.achievement.bugSquasher"
        case dodoRevenge             = "com.whowouldin.achievement.dodoRevenge"
        case shrimpKing              = "com.whowouldin.achievement.shrimpKing"

        // ── Specific Animal Wins (12) ──
        case honeyDontCare           = "com.whowouldin.achievement.honeyDontCare"
        case holdMyHoney             = "com.whowouldin.achievement.holdMyHoney"
        case releaseTheKraken        = "com.whowouldin.achievement.releaseTheKraken"
        case thunderstruck           = "com.whowouldin.achievement.thunderstruck"
        case kingOfTheJungle         = "com.whowouldin.achievement.kingOfTheJungle"
        case jaws                    = "com.whowouldin.achievement.jaws"
        case cleverGirl              = "com.whowouldin.achievement.cleverGirl"
        case phoenixRising           = "com.whowouldin.achievement.phoenixRising"
        case stoneCold               = "com.whowouldin.achievement.stoneCold"
        case herculeanEffort         = "com.whowouldin.achievement.herculeanEffort"
        case threeHeadedTerror       = "com.whowouldin.achievement.threeHeadedTerror"
        case dragonSlayer            = "com.whowouldin.achievement.dragonSlayer"

        // ── Environment (8) ──
        case homeTurf                = "com.whowouldin.achievement.homeTurf"
        case fishOutOfWater          = "com.whowouldin.achievement.fishOutOfWater"
        case fireWalker              = "com.whowouldin.achievement.fireWalker"
        case stormChaser             = "com.whowouldin.achievement.stormChaser"
        case nightHunter             = "com.whowouldin.achievement.nightHunter"
        case frozenFight             = "com.whowouldin.achievement.frozenFight"
        case jungleFever             = "com.whowouldin.achievement.jungleFever"
        case worldTraveler           = "com.whowouldin.achievement.worldTraveler"

        // ── Tournament (10) ──
        case tournamentRookie        = "com.whowouldin.achievement.tournamentRookie"
        case bracketBuster           = "com.whowouldin.achievement.bracketBuster"
        case grandChampion           = "com.whowouldin.achievement.grandChampion"
        case perfectBracket          = "com.whowouldin.achievement.perfectBracket"
        case highRoller              = "com.whowouldin.achievement.highRoller"
        case kaChing                 = "com.whowouldin.achievement.kaChing"
        case landLubber              = "com.whowouldin.achievement.landLubber"
        case seaSupremacy            = "com.whowouldin.achievement.seaSupremacy"
        case airForceOne             = "com.whowouldin.achievement.airForceOne"
        case tournamentVeteran       = "com.whowouldin.achievement.tournamentVeteran"

        // ── Coins (4) ──
        case piggyBank               = "com.whowouldin.achievement.piggyBank"
        case fatCat                   = "com.whowouldin.achievement.fatCat"
        case dragonsHoard             = "com.whowouldin.achievement.dragonsHoard"
        case bigSpender               = "com.whowouldin.achievement.bigSpender"

        // ── Streaks (4) ──
        case onARoll                 = "com.whowouldin.achievement.onARoll"
        case dedicated               = "com.whowouldin.achievement.dedicated"
        case unstoppable             = "com.whowouldin.achievement.unstoppable"
        case obsessed                = "com.whowouldin.achievement.obsessed"

        // ── Pack Unlocks (5) ──
        case jurassicSpark           = "com.whowouldin.achievement.jurassicSpark"
        case onceUponATime           = "com.whowouldin.achievement.onceUponATime"
        case mythMaker               = "com.whowouldin.achievement.mythMaker"
        case ascendingOlympus        = "com.whowouldin.achievement.ascendingOlympus"
        case gottaCatchEmAll         = "com.whowouldin.achievement.gottaCatchEmAll"

        // ── Custom Creatures (3) ──
        case creatureCreator         = "com.whowouldin.achievement.creatureCreator"
        case imaginationStation      = "com.whowouldin.achievement.imaginationStation"
        case madScientist            = "com.whowouldin.achievement.madScientist"

        // ── Fun / Weird (8) ──
        case closeCall               = "com.whowouldin.achievement.closeCall"
        case flawlessVictory         = "com.whowouldin.achievement.flawlessVictory"
        case itsADraw                = "com.whowouldin.achievement.itsADraw"
        case offlineWarrior          = "com.whowouldin.achievement.offlineWarrior"
        case voiceCommander          = "com.whowouldin.achievement.voiceCommander"
        case nightOwl                = "com.whowouldin.achievement.nightOwl"
        case earlyBird               = "com.whowouldin.achievement.earlyBird"
        case marathoner              = "com.whowouldin.achievement.marathoner"
    }

    // MARK: - Tracking Keys (persisted in UserDefaults, synced via iCloud)

    private enum Key {
        static let earned              = "achievement.earned"
        static let environmentsWon     = "achievement.environmentsWon"
        static let customCreaturesUsed = "achievement.customCreaturesUsed"
        static let totalCoinsSpent     = "achievement.totalCoinsSpent"
        static let tournamentsCompleted = "achievement.tournamentsCompleted"
        static let sessionBattleCount  = "achievement.sessionBattleCount"
        static let categoriesBattled   = "achievement.categoriesBattled"
        static let uniqueAnimalsUsed   = "achievement.uniqueAnimalsUsed"
    }

    // MARK: - Earned Check

    private var earnedSet: Set<String> {
        Set(defaults.stringArray(forKey: Key.earned) ?? [])
    }

    private func isEarned(_ achievement: AchievementID) -> Bool {
        earnedSet.contains(achievement.rawValue)
    }

    private func markEarned(_ achievement: AchievementID) {
        var earned = earnedSet
        guard !earned.contains(achievement.rawValue) else { return }
        earned.insert(achievement.rawValue)
        defaults.set(Array(earned), forKey: Key.earned)
        GameCenterManager.shared.reportAchievement(achievement.rawValue)
        CloudSyncService.shared.autoSync()
    }

    // MARK: - Array Tracking Helpers

    private func addToArrayKey(_ key: String, value: String) {
        var arr = Set(defaults.stringArray(forKey: key) ?? [])
        arr.insert(value)
        defaults.set(Array(arr), forKey: key)
    }

    private func arrayCount(_ key: String) -> Int {
        (defaults.stringArray(forKey: key) ?? []).count
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 🎮 BATTLE COMPLETE
    // Called after every battle (normal or tournament).
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func checkBattleAchievements(
        fighter1: Animal,
        fighter2: Animal,
        result: BattleResult,
        environment: BattleEnvironment
    ) {
        let battleCount = UserSettings.shared.totalBattleCount
        let isDraw = result.winner == "draw"
        let winnerId = result.winner
        let winnerAnimal = winnerId == fighter1.id ? fighter1 : fighter2
        let loserAnimal = winnerId == fighter1.id ? fighter2 : fighter1

        // Track unique animals and categories used
        addToArrayKey(Key.uniqueAnimalsUsed, value: fighter1.id)
        addToArrayKey(Key.uniqueAnimalsUsed, value: fighter2.id)
        addToArrayKey(Key.categoriesBattled, value: fighter1.category.rawValue)
        addToArrayKey(Key.categoriesBattled, value: fighter2.category.rawValue)

        // Track session battles (resets on app launch, see resetSessionCount)
        let sessionCount = defaults.integer(forKey: Key.sessionBattleCount) + 1
        defaults.set(sessionCount, forKey: Key.sessionBattleCount)

        // ── Battle Milestones ──
        let milestones: [(Int, AchievementID)] = [
            (1, .firstFight), (10, .tenBattles), (50, .fiftyBattles),
            (100, .hundredBattles), (250, .twoFiftyBattles), (500, .fiveHundredBattles),
            (1000, .thousandBattles), (5000, .fiveThousandBattles), (10000, .tenThousandBattles)
        ]
        for (threshold, achievement) in milestones {
            if battleCount >= threshold && !isEarned(achievement) {
                markEarned(achievement)
            }
        }
        // Report progress on the NEXT unearned milestone
        for (threshold, achievement) in milestones {
            if !isEarned(achievement) {
                let pct = Double(battleCount) / Double(threshold) * 100
                GameCenterManager.shared.reportProgress(achievement.rawValue, percentComplete: pct)
                break
            }
        }

        // ── Category Mashups ──
        let cats = Set([fighter1.category, fighter2.category])

        if cats.contains(.land) && cats.contains(.sea) { markEarned(.surfAndTurf) }
        if cats.contains(.land) && cats.contains(.air) { markEarned(.whenPigsFly) }
        if cats.contains(.air) && cats.contains(.insect) { markEarned(.bugZapper) }
        if fighter1.category == .prehistoric && fighter2.category == .prehistoric { markEarned(.prehistoricShowdown) }
        if fighter1.category == .mythic && fighter2.category == .mythic { markEarned(.mythVsMyth) }
        if fighter1.category == .olympus && fighter2.category == .olympus { markEarned(.godFight) }
        if fighter1.category == .fantasy && fighter2.category == .fantasy { markEarned(.fantasyRumble) }

        // Category Collector: battled creatures from 5+ different categories
        if arrayCount(Key.categoriesBattled) >= 5 { markEarned(.categoryCollector) }

        // ── Draw ──
        if isDraw {
            markEarned(.itsADraw)
            CloudSyncService.shared.autoSync()
            return  // No winner-dependent achievements for draws
        }

        // ── Upset Achievements ──
        // David vs Goliath: size 1-2 beats size 4-5
        if winnerAnimal.size <= 2 && loserAnimal.size >= 4 { markEarned(.davidVsGoliath) }

        // God Slayer: non-olympus beats olympus
        if winnerAnimal.category != .olympus && loserAnimal.category == .olympus { markEarned(.godSlayer) }

        // Bug Squasher: insect beats size 4+
        if winnerAnimal.category == .insect && loserAnimal.size >= 4 { markEarned(.bugSquasher) }

        // Dodo's Revenge: win with dodo
        if winnerId == "dodo" { markEarned(.dodoRevenge) }

        // Shrimp King: win with mantis shrimp
        if winnerId == "mantis_shrimp" { markEarned(.shrimpKing) }

        // ── Specific Animal Wins ──
        if winnerId == "honey_badger" {
            markEarned(.honeyDontCare)
            // Hold My Honey: Honey Badger beats an Olympus god
            if loserAnimal.category == .olympus { markEarned(.holdMyHoney) }
        }
        if winnerId == "kraken"        { markEarned(.releaseTheKraken) }
        if winnerId == "zeus"          { markEarned(.thunderstruck) }
        if winnerId == "lion"          { markEarned(.kingOfTheJungle) }
        if winnerId == "great_white_shark" { markEarned(.jaws) }
        if winnerId == "velociraptor"  { markEarned(.cleverGirl) }
        if winnerId == "phoenix"       { markEarned(.phoenixRising) }
        if winnerId == "medusa"        { markEarned(.stoneCold) }
        if winnerId == "hercules"      { markEarned(.herculeanEffort) }
        if winnerId == "cerberus"      { markEarned(.threeHeadedTerror) }

        // Dragon Slayer: beat the dragon (dragon must LOSE)
        if loserAnimal.id == "dragon" && !isDraw { markEarned(.dragonSlayer) }

        // ── Environment Achievements ──
        // Track this environment as "won in"
        addToArrayKey(Key.environmentsWon, value: environment.rawValue)

        // Home Turf: sea creature wins in ocean
        if winnerAnimal.category == .sea && environment == .ocean { markEarned(.homeTurf) }

        // Fish Out of Water: sea creature wins in desert
        if winnerAnimal.category == .sea && environment == .desert { markEarned(.fishOutOfWater) }

        // Specific environment wins
        if environment == .volcano { markEarned(.fireWalker) }
        if environment == .storm  { markEarned(.stormChaser) }
        if environment == .night  { markEarned(.nightHunter) }
        if environment == .arctic { markEarned(.frozenFight) }
        if environment == .jungle { markEarned(.jungleFever) }

        // World Traveler: won in all 9 environments
        if arrayCount(Key.environmentsWon) >= 9 { markEarned(.worldTraveler) }

        // ── Battle Outcome Achievements ──
        // Close Call: win with < 20% health
        if result.winnerHealthPercent < 20 { markEarned(.closeCall) }

        // Flawless Victory: win with 85%+ health
        if result.winnerHealthPercent >= 85 { markEarned(.flawlessVictory) }

        // Offline Warrior
        if result.isOfflineFallback { markEarned(.offlineWarrior) }

        // ── Custom Creature ──
        if fighter1.isCustom || fighter2.isCustom {
            markEarned(.creatureCreator)
            let customName = fighter1.isCustom ? fighter1.id : fighter2.id
            addToArrayKey(Key.customCreaturesUsed, value: customName)
            if arrayCount(Key.customCreaturesUsed) >= 5 { markEarned(.imaginationStation) }
            if arrayCount(Key.customCreaturesUsed) >= 10 { markEarned(.madScientist) }
        }

        // ── Time-based ──
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 5 { markEarned(.nightOwl) }
        if hour >= 5 && hour < 7 { markEarned(.earlyBird) }

        // ── Session Marathon ──
        if sessionCount >= 10 { markEarned(.marathoner) }

        CloudSyncService.shared.autoSync()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 🏆 TOURNAMENT COMPLETE
    // Called when a tournament finishes.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func checkTournamentAchievements(
        bracketSize: Int,
        championCategory: AnimalCategory?,
        grandChampionWon: Bool,
        allWagersCorrect: Bool,
        totalWagered: Int,
        totalWon: Int
    ) {
        // Track tournaments completed
        let count = defaults.integer(forKey: Key.tournamentsCompleted) + 1
        defaults.set(count, forKey: Key.tournamentsCompleted)

        // Report tournaments-completed count to Game Center leaderboard
        GameCenterManager.shared.reportScore(.tournamentsWon, value: count)

        markEarned(.tournamentRookie)

        if bracketSize >= 16 { markEarned(.bracketBuster) }
        if grandChampionWon  { markEarned(.grandChampion) }
        if allWagersCorrect  { markEarned(.perfectBracket) }
        if totalWagered >= 500 { markEarned(.highRoller) }
        if totalWon >= 1000  { markEarned(.kaChing) }

        if let cat = championCategory {
            switch cat {
            case .land: markEarned(.landLubber)
            case .sea:  markEarned(.seaSupremacy)
            case .air:  markEarned(.airForceOne)
            default: break
            }
        }

        if count >= 10 { markEarned(.tournamentVeteran) }

        // Report progress toward tournament veteran
        if !isEarned(.tournamentVeteran) {
            GameCenterManager.shared.reportProgress(
                AchievementID.tournamentVeteran.rawValue,
                percentComplete: Double(count) / 10.0 * 100
            )
        }

        CloudSyncService.shared.autoSync()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 💰 COIN CHANGES
    // Called after any coin balance change.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func checkCoinAchievements(balance: Int) {
        if balance >= 1000  { markEarned(.piggyBank) }
        if balance >= 5000  { markEarned(.fatCat) }
        if balance >= 10000 { markEarned(.dragonsHoard) }

        // Report progress toward Dragon's Hoard
        if !isEarned(.dragonsHoard) {
            GameCenterManager.shared.reportProgress(
                AchievementID.dragonsHoard.rawValue,
                percentComplete: Double(balance) / 10000.0 * 100
            )
        }
    }

    func trackCoinsSpent(_ amount: Int) {
        let total = defaults.integer(forKey: Key.totalCoinsSpent) + amount
        defaults.set(total, forKey: Key.totalCoinsSpent)
        if total >= 5000 { markEarned(.bigSpender) }

        if !isEarned(.bigSpender) {
            GameCenterManager.shared.reportProgress(
                AchievementID.bigSpender.rawValue,
                percentComplete: Double(total) / 5000.0 * 100
            )
        }
        CloudSyncService.shared.autoSync()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 🔥 STREAK CHANGES
    // Called after streak updates.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func checkStreakAchievements(streak: Int) {
        if streak >= 3  { markEarned(.onARoll) }
        if streak >= 7  { markEarned(.dedicated) }
        if streak >= 14 { markEarned(.unstoppable) }
        if streak >= 30 { markEarned(.obsessed) }

        // Report progress toward Obsessed
        if !isEarned(.obsessed) {
            GameCenterManager.shared.reportProgress(
                AchievementID.obsessed.rawValue,
                percentComplete: Double(streak) / 30.0 * 100
            )
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 📦 PACK UNLOCKS
    // Called when a pack is unlocked (via coins, IAP, or milestone).
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func checkPackAchievements() {
        let settings = UserSettings.shared

        if settings.isPrehistoricUnlocked { markEarned(.jurassicSpark) }
        if settings.isFantasyUnlocked     { markEarned(.onceUponATime) }
        if settings.isMythicUnlocked      { markEarned(.mythMaker) }
        if settings.isOlympusUnlocked     { markEarned(.ascendingOlympus) }

        // Gotta Catch 'Em All: all 4 packs unlocked
        if settings.isPrehistoricUnlocked && settings.isFantasyUnlocked &&
           settings.isMythicUnlocked && settings.isOlympusUnlocked {
            markEarned(.gottaCatchEmAll)
        }

        CloudSyncService.shared.autoSync()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 🎤 VOICE SEARCH
    // Called when user picks a fighter via voice.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    func trackVoiceSearch() {
        markEarned(.voiceCommander)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Session Management
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Call on app launch to reset per-session counters.
    func resetSessionCount() {
        defaults.set(0, forKey: Key.sessionBattleCount)
    }
}
