import Foundation
import Combine

final class AnimalPickerViewModel: ObservableObject {
    @Published var fighter1: Animal? = nil
    @Published var fighter2: Animal? = nil
    @Published var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
            // Reset emoji when search changes so we don't show stale info
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                customAnimalEmoji = "🐾"
                customAnimalCategory = .land
                customAnimalColor = "#888888"
                customAnimalImageURL = nil
            }
        }
    }
    @Published var selectedCategory: AnimalCategory = .all
    @Published var selectedEnvironment: BattleEnvironment = .grassland
    @Published var arenaEffectsEnabled: Bool = false

    // Custom animal published state
    @Published var customAnimalEmoji: String = "🐾"
    @Published var customAnimalCategory: AnimalCategory = .land
    @Published var customAnimalColor: String = "#888888"
    /// Best available image URL for the custom animal (Wikipedia or Pollinations).
    /// nil while loading; always set once fetchCustomAnimalInfo() completes.
    @Published var customAnimalImageURL: URL? = nil

    private var cancellables = Set<AnyCancellable>()
    private let searchTextSubject = PassthroughSubject<String, Never>()

    init() {
        // Debounce search text changes to fetch custom animal info
        searchTextSubject
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self else { return }
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                // Only fetch if there are no matching built-in animals
                let hasMatches = Animals.all.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                if !hasMatches {
                    Task {
                        await self.fetchCustomAnimalInfo()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed

    var filteredAnimals: [Animal] {
        Animals.all.filter { animal in
            // Olympus gods: visible via cheat code OR legitimate unlock
            if animal.category == .olympus
                && !CheatState.shared.olympusUnlocked
                && !UserSettings.shared.isOlympusUnlocked { return false }
            let categoryMatch = selectedCategory == .all || animal.category == selectedCategory
            let searchMatch = searchText.isEmpty || animal.name.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && searchMatch
        }
    }

    var canFight: Bool {
        fighter1 != nil && fighter2 != nil
    }

    /// Returns a known-but-locked animal if the search text matches one the user hasn't unlocked.
    /// Used to show an "unlock required" prompt instead of treating it as a custom animal.
    var lockedAnimal: Animal? {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, filteredAnimals.isEmpty else { return nil }
        return Animals.all.first { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var customAnimal: Animal? {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty,
              filteredAnimals.isEmpty,
              lockedAnimal == nil else { return nil }
        let name = searchText.trimmingCharacters(in: .whitespaces)
        guard ContentFilter.isAppropriate(name) else { return nil }
        return Animal(
            id: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: name.capitalized,
            emoji: customAnimalEmoji,
            category: customAnimalCategory,
            pixelColor: customAnimalColor,
            size: 3,
            isCustom: true,
            imageURL: customAnimalImageURL
        )
    }

    // MARK: - Custom Animal Info Fetch

    @MainActor
    func fetchCustomAnimalInfo() async {
        let name = searchText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, ContentFilter.isAppropriate(name) else { return }

        // Fetch emoji/category/color and image URL concurrently
        async let infoTask  = AnimalImageService.shared.fetchAnimalInfo(name: name)
        async let imageTask = AnimalImageService.shared.imageURL(for: name)

        let (emoji, category, color) = await infoTask
        let imageURL = await imageTask

        // Only apply if the search text hasn't changed while we were fetching
        guard searchText.trimmingCharacters(in: .whitespaces) == name else { return }
        customAnimalEmoji    = emoji
        customAnimalCategory = category
        customAnimalColor    = color
        customAnimalImageURL = imageURL
    }

    // MARK: - Selection

    /// Convenience alias used by the custom-animal button in AnimalPickerView.
    /// Clears search text after selection so the grid is immediately ready for the next pick.
    func selectAnimal(_ animal: Animal) {
        select(animal)
        searchText = ""
    }

    /// Select an animal into the next available slot.
    /// - Slot 1 empty → fill slot 1
    /// - Slot 1 filled, slot 2 empty → fill slot 2
    /// - Both filled → replace slot 2 (most recently filled)
    /// - Prevents selecting the same animal in both slots
    func select(_ animal: Animal) {
        if fighter1 == nil {
            fighter1 = animal
        } else if fighter2 == nil {
            // Don't allow the same animal in both slots
            guard animal != fighter1 else { return }
            fighter2 = animal
        } else {
            // Both filled — replace slot 2, but don't duplicate slot 1
            guard animal != fighter1 else { return }
            fighter2 = animal
        }
    }

    func clear(_ slot: Int) {
        switch slot {
        case 1:
            fighter1 = nil
        case 2:
            fighter2 = nil
        default:
            break
        }
    }

    func reset() {
        fighter1 = nil
        fighter2 = nil
        searchText = ""
        selectedCategory = .all
        selectedEnvironment = .grassland
        customAnimalEmoji = "🐾"
        customAnimalCategory = .land
        customAnimalColor = "#888888"
        customAnimalImageURL = nil
    }
}
