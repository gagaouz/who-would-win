import CarPlay
import UIKit

// MARK: - CarPlayCoordinator

/// Drives every CarPlay template and the battle state machine.
///
/// UI structure:
///   CPTabBarTemplate
///   ├── ⚔️  Battle   (CPListTemplate)  — pick fighters, pick arena, start fight
///   └── 🐾  Animals  (CPListTemplate)  — browse all animals by category
///
/// Battle flow:
///   Pick F1 → Pick F2 → (optional) Pick Arena → Start Battle
///   → Loading screen (CPInformationTemplate)
///   → Result screen  (CPInformationTemplate) + voice narration
@MainActor
final class CarPlayCoordinator: NSObject {

    // MARK: - Properties

    let interfaceController: CPInterfaceController
    private let speaker      = CarPlaySpeaker()
    private let battleService = BattleService()

    private var fighter1: Animal?  { didSet { refreshBattleTab() } }
    private var fighter2: Animal?  { didSet { refreshBattleTab() } }
    private var arena: BattleEnvironment = .grassland { didSet { refreshBattleTab() } }
    private var isBattling = false

    private var battleListTemplate: CPListTemplate?

    // MARK: - Init

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    // MARK: - Lifecycle

    func start() {
        let battleTab  = makeBattleListTemplate()
        battleListTemplate = battleTab
        battleTab.tabTitle = "Battle"
        battleTab.tabImage = UIImage(systemName: "bolt.fill")

        let animalsTab = makeAllAnimalsTemplate(pickingSlot: nil)
        animalsTab.tabTitle = "Animals"
        animalsTab.tabImage = UIImage(systemName: "pawprint.fill")

        let tabBar = CPTabBarTemplate(templates: [battleTab, animalsTab])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
    }

    func tearDown() {
        speaker.stopSpeaking()
    }

    // MARK: - Battle Tab

    private func makeBattleListTemplate() -> CPListTemplate {
        CPListTemplate(title: "Animal vs Animal", sections: makeBattleSections())
    }

    private func makeBattleSections() -> [CPListSection] {
        // ── FIGHTERS ────────────────────────────────────────────────────
        let f1 = makeFighterItem(slot: 1)
        let f2 = makeFighterItem(slot: 2)
        let fightersSection = CPListSection(
            items: [f1, f2],
            header: "⚔️  FIGHTERS",
            sectionIndexTitle: nil
        )

        // ── ARENA ───────────────────────────────────────────────────────
        let arenaItem = CPListItem(
            text: "\(arena.emoji)  \(arena.name)",
            detailText: arena.tagline
        )
        arenaItem.handler = { [weak self] _, completion in
            self?.showArenaPicker()
            completion()
        }
        let arenaSection = CPListSection(
            items: [arenaItem],
            header: "🏟️  ARENA",
            sectionIndexTitle: nil
        )

        // ── FIGHT ───────────────────────────────────────────────────────
        var fightItems: [CPListItem] = []

        // Quick battle — always available
        let quickItem = CPListItem(
            text: "⚡  Quick Random Battle",
            detailText: "Random fighters, instant result"
        )
        quickItem.handler = { [weak self] _, completion in
            self?.startQuickBattle()
            completion()
        }
        fightItems.append(quickItem)

        // Manual battle — only when both fighters are set
        if let f1 = fighter1, let f2 = fighter2 {
            let battleItem = CPListItem(
                text: "⚔️  BATTLE!",
                detailText: "\(f1.emoji) \(f1.name)  vs  \(f2.emoji) \(f2.name)"
            )
            battleItem.handler = { [weak self] _, completion in
                self?.startBattle()
                completion()
            }
            fightItems.append(battleItem)
        }

        let fightSection = CPListSection(
            items: fightItems,
            header: "🥊  FIGHT",
            sectionIndexTitle: nil
        )

        return [fightersSection, arenaSection, fightSection]
    }

    private func makeFighterItem(slot: Int) -> CPListItem {
        let animal    = slot == 1 ? fighter1 : fighter2
        let slotLabel = slot == 1 ? "Fighter 1" : "Fighter 2"

        if let a = animal {
            let item = CPListItem(
                text: "\(a.emoji)  \(a.name)",
                detailText: "\(slotLabel) · \(a.category.rawValue.capitalized) · Size \(a.size)"
            )
            item.image = emojiImage(a.emoji, size: 44)
            item.handler = { [weak self] _, completion in
                self?.showAnimalPicker(forSlot: slot)
                completion()
            }
            return item
        }

        let item = CPListItem(
            text: slotLabel,
            detailText: "Tap to choose an animal"
        )
        item.image = UIImage(systemName: "plus.circle")?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
        item.handler = { [weak self] _, completion in
            self?.showAnimalPicker(forSlot: slot)
            completion()
        }
        return item
    }

    private func refreshBattleTab() {
        battleListTemplate?.updateSections(makeBattleSections())
    }

    // MARK: - Animal Picker

    private func showAnimalPicker(forSlot slot: Int) {
        let template = makeAllAnimalsTemplate(pickingSlot: slot)
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    private func makeAllAnimalsTemplate(pickingSlot slot: Int?) -> CPListTemplate {
        let title = slot == nil ? "Animals" : "Pick \(slot == 1 ? "Fighter 1" : "Fighter 2")"
        let settings = UserSettings.shared

        let orderedCategories: [AnimalCategory] = [
            .land, .sea, .air, .insect, .prehistoric, .fantasy, .mythic
        ]

        var sections: [CPListSection] = []

        for category in orderedCategories {
            let isUnlocked: Bool = {
                switch category {
                case .prehistoric: return settings.isPrehistoricUnlocked
                case .fantasy:     return settings.isFantasyUnlocked
                case .mythic:      return settings.isMythicUnlocked
                default:           return true
                }
            }()

            let animalsInCategory = Animals.all.filter { $0.category == category }
            guard !animalsInCategory.isEmpty else { continue }

            let items: [CPListItem] = animalsInCategory.map { animal in
                let item = CPListItem(
                    text: "\(animal.emoji)  \(animal.name)",
                    detailText: isUnlocked
                        ? "Size \(animal.size) · \(animal.category.rawValue.capitalized)"
                        : "🔒 Locked — keep battling to unlock"
                )
                item.image = emojiImage(animal.emoji, size: 44)

                if isUnlocked {
                    if let slot = slot {
                        item.handler = { [weak self] _, completion in
                            self?.didSelectAnimal(animal, forSlot: slot)
                            completion()
                        }
                    } else {
                        item.handler = { [weak self] _, completion in
                            self?.didSelectAnimalFromBrowse(animal)
                            completion()
                        }
                    }
                }
                return item
            }

            let lockedSuffix = isUnlocked ? "" : "  🔒"
            let header = "\(categoryEmoji(for: category))  \(category.rawValue.uppercased())\(lockedSuffix)"
            sections.append(CPListSection(items: items, header: header, sectionIndexTitle: nil))
        }

        return CPListTemplate(title: title, sections: sections)
    }

    private func didSelectAnimal(_ animal: Animal, forSlot slot: Int) {
        if slot == 1 {
            fighter1 = animal
            if fighter2?.id == animal.id { fighter2 = nil }
        } else {
            fighter2 = animal
            if fighter1?.id == animal.id { fighter1 = nil }
        }
        interfaceController.popTemplate(animated: true, completion: nil)
        speaker.speak("\(animal.name) set as fighter \(slot).", rate: 0.52)

        // Auto-prompt for the other slot if empty
        if slot == 1 && fighter2 == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.speaker.speak("Now pick fighter 2.", rate: 0.52)
            }
        } else if slot == 2 && fighter1 != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.speaker.speak("Tap Battle to start the fight!", rate: 0.52)
            }
        }
    }

    private func didSelectAnimalFromBrowse(_ animal: Animal) {
        if fighter1 == nil {
            fighter1 = animal
            speaker.speak("\(animal.name) set as fighter 1. Pick fighter 2 to battle!", rate: 0.52)
        } else if fighter2 == nil, fighter1?.id != animal.id {
            fighter2 = animal
            speaker.speak("\(animal.name) set as fighter 2. Head to Battle to start!", rate: 0.52)
        } else {
            fighter2 = animal
            speaker.speak("\(animal.name) set as fighter 2.", rate: 0.52)
        }
    }

    // MARK: - Arena Picker

    private func showArenaPicker() {
        let settings = UserSettings.shared

        let items: [CPListItem] = BattleEnvironment.allCases.map { env in
            let isUnlocked = settings.isEnvironmentUnlocked(env)
            let item = CPListItem(
                text: "\(env.emoji)  \(env.name)",
                detailText: isUnlocked ? env.tagline : "🔒 Locked"
            )
            if isUnlocked {
                item.handler = { [weak self] _, completion in
                    self?.arena = env
                    self?.interfaceController.popTemplate(animated: true, completion: nil)
                    self?.speaker.speak("\(env.name) arena selected.", rate: 0.52)
                    completion()
                }
            }
            return item
        }

        let section  = CPListSection(items: items, header: "Choose Arena", sectionIndexTitle: nil)
        let template = CPListTemplate(title: "Arena", sections: [section])
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }

    // MARK: - Quick Battle

    private func startQuickBattle() {
        guard !isBattling else { return }

        // Pick from land/sea/air for accessible quick battles
        let pool = Animals.all.filter { [.land, .sea, .air].contains($0.category) }.shuffled()
        guard pool.count >= 2 else { return }

        let f1 = pool[0]
        let f2 = pool.first(where: { $0.id != f1.id }) ?? pool[1]

        // Set without triggering two refreshBattleTab calls
        fighter1 = f1
        fighter2 = f2

        startBattle()
    }

    // MARK: - Battle Engine

    private func startBattle() {
        guard let f1 = fighter1, let f2 = fighter2, !isBattling else { return }
        isBattling = true

        // Show loading screen
        let loading = makeLoadingTemplate(fighter1: f1, fighter2: f2)
        interfaceController.pushTemplate(loading, animated: true, completion: nil)

        speaker.speak("\(f1.name) versus \(f2.name), in the \(arena.name). Let the battle begin!")

        Task {
            do {
                let result = try await battleService.fetchBattleResult(
                    fighter1: f1, fighter2: f2, environment: arena
                )
                self.isBattling = false
                UserSettings.shared.recordBattle()
                CoinStore.shared.earnBattleCoins()
                self.presentResult(result, fighter1: f1, fighter2: f2)
            } catch {
                self.isBattling = false
                self.interfaceController.popTemplate(animated: true, completion: nil)
                self.speaker.speak("The battle could not be determined. Please try again.")
            }
        }
    }

    private func makeLoadingTemplate(fighter1: Animal, fighter2: Animal) -> CPInformationTemplate {
        let items: [CPInformationItem] = [
            CPInformationItem(title: "Fighter 1", detail: "\(fighter1.emoji)  \(fighter1.name)"),
            CPInformationItem(title: "Fighter 2", detail: "\(fighter2.emoji)  \(fighter2.name)"),
            CPInformationItem(title: "Arena",     detail: "\(arena.emoji)  \(arena.name)"),
            CPInformationItem(title: "Status",    detail: "⚡  Calculating outcome…"),
        ]
        return CPInformationTemplate(
            title: "⚔️  Battle in progress…",
            layout: .leading,
            items: items,
            actions: []
        )
    }

    // MARK: - Battle Result

    private func presentResult(_ result: BattleResult, fighter1: Animal, fighter2: Animal) {
        // Replace loading screen with result (no back stack)
        interfaceController.popTemplate(animated: false, completion: nil)

        let isDraw  = result.winner == "draw"
        let winner  = isDraw ? nil : (result.winner == fighter1.id ? fighter1 : fighter2)
        let loser   = isDraw ? nil : (result.winner == fighter1.id ? fighter2 : fighter1)

        let titleText: String = {
            if let w = winner { return "🏆  \(w.name.uppercased()) WINS!" }
            return "⚔️  IT'S A DRAW!"
        }()

        var items: [CPInformationItem] = [
            CPInformationItem(title: "Fighter 1", detail: "\(fighter1.emoji)  \(fighter1.name)"),
            CPInformationItem(title: "Fighter 2", detail: "\(fighter2.emoji)  \(fighter2.name)"),
            CPInformationItem(title: "Arena",     detail: "\(arena.emoji)  \(arena.name)"),
        ]

        if let w = winner, let l = loser {
            items += [
                CPInformationItem(title: "\(w.emoji)  \(w.name) HP", detail: "▓▓▓▓  \(result.winnerHealthPercent)%"),
                CPInformationItem(title: "\(l.emoji)  \(l.name) HP", detail: "░░░░  \(result.loserHealthPercent)%"),
            ]
        }

        // Trim narration to ≤2 sentences for readability on small screens
        let narration = result.narration
            .components(separatedBy: ". ")
            .prefix(2)
            .joined(separator: ". ")
            .appending(".")

        items.append(CPInformationItem(title: "Battle", detail: narration))
        items.append(CPInformationItem(title: "Fun Fact", detail: result.funFact))

        // Actions
        let rematch = CPTextButton(title: "⚔️  Rematch", textStyle: .confirm) { [weak self] _ in
            self?.interfaceController.popTemplate(animated: true) { [weak self] _, _ in
                self?.startBattle()
            }
        }

        let newBattle = CPTextButton(title: "🐾  New Battle", textStyle: .normal) { [weak self] _ in
            self?.fighter1 = nil
            self?.fighter2 = nil
            self?.interfaceController.popTemplate(animated: true, completion: nil)
        }

        let resultTemplate = CPInformationTemplate(
            title: titleText,
            layout: .leading,
            items: items,
            actions: [rematch, newBattle]
        )

        interfaceController.pushTemplate(resultTemplate, animated: true, completion: nil)

        // Speak narration after template transition settles
        let speechText: String = {
            if let w = winner {
                return "\(w.name) wins! \(result.narration)"
            }
            return "It's a draw! \(result.narration)"
        }()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.speaker.speak(speechText)
        }
    }

    // MARK: - Helpers

    /// Renders an emoji string as a square UIImage for use in CarPlay list items.
    private func emojiImage(_ emoji: String, size: CGFloat = 44) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { _ in
            let fontSize  = size * 0.72
            let font      = UIFont.systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let str       = emoji as NSString
            let textSize  = str.size(withAttributes: attrs)
            let origin    = CGPoint(x: (size - textSize.width)  / 2,
                                    y: (size - textSize.height) / 2)
            str.draw(at: origin, withAttributes: attrs)
        }
    }

    private func categoryEmoji(for category: AnimalCategory) -> String {
        switch category {
        case .land:        return "🦁"
        case .sea:         return "🦈"
        case .air:         return "🦅"
        case .insect:      return "🐛"
        case .prehistoric: return "🦕"
        case .fantasy:     return "🐉"
        case .mythic:      return "⚡️"
        case .olympus:     return "⚡"
        case .all:         return "🌍"
        }
    }
}
