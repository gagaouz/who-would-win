import XCTest
@testable import WhoWouldWin

final class BattleServiceTests: XCTestCase {

    // Test 1: All 143 creatures exist and have valid IDs
    func testAllAnimalIDsAreValid() {
        XCTAssertEqual(Animals.all.count, 143, "Should have exactly 143 creatures")
        for animal in Animals.all {
            XCTAssertFalse(animal.id.isEmpty, "Animal ID should not be empty: \(animal.name)")
            XCTAssertFalse(animal.name.isEmpty, "Animal name should not be empty")
            XCTAssertFalse(animal.emoji.isEmpty, "Animal emoji should not be empty")
            XCTAssertTrue(1...5 ~= animal.size, "Animal size should be 1-5: \(animal.name)")
        }
    }

    // Test 2: AnimalPickerViewModel fills slots correctly
    func testPickerFillsSlotsInOrder() {
        let vm = AnimalPickerViewModel()
        let lion = Animals.all.first { $0.id == "lion" }!
        let tiger = Animals.all.first { $0.id == "tiger" }!

        vm.select(lion)
        XCTAssertEqual(vm.fighter1?.id, "lion", "First selection should go to slot 1")
        XCTAssertNil(vm.fighter2, "Slot 2 should be empty")

        vm.select(tiger)
        XCTAssertEqual(vm.fighter2?.id, "tiger", "Second selection should go to slot 2")
    }

    // Test 3: Selecting when both slots are full replaces slot 2
    func testPickerReplacesMostRecentSlotWhenFull() {
        let vm = AnimalPickerViewModel()
        let lion = Animals.all.first { $0.id == "lion" }!
        let tiger = Animals.all.first { $0.id == "tiger" }!
        let bear = Animals.all.first { $0.id == "grizzly_bear" }!

        vm.select(lion)
        vm.select(tiger)
        vm.select(bear) // Should replace slot 2

        XCTAssertEqual(vm.fighter1?.id, "lion", "Slot 1 should remain lion")
        XCTAssertEqual(vm.fighter2?.id, "grizzly_bear", "Slot 2 should now be bear")
    }

    // Test 4: BattleResult JSON decoding
    func testBattleResultDecoding() throws {
        let json = """
        {
            "winner": "lion",
            "narration": "The lion charged with a mighty roar! The tiger fell back in defeat.",
            "funFact": "Lions can run up to 50 mph in short bursts.",
            "winnerHealthPercent": 75,
            "loserHealthPercent": 15
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(BattleResult.self, from: json)
        XCTAssertEqual(result.winner, "lion")
        XCTAssertEqual(result.winnerHealthPercent, 75)
        XCTAssertEqual(result.loserHealthPercent, 15)
        XCTAssertFalse(result.narration.isEmpty)
    }

    // Test 5: filteredAnimals correctly filters by category
    func testFilteredAnimalsByCategory() {
        let vm = AnimalPickerViewModel()
        vm.selectedCategory = .sea
        let seaAnimals = vm.filteredAnimals
        XCTAssertTrue(seaAnimals.allSatisfy { $0.category == .sea }, "All filtered animals should be sea category")
        XCTAssertGreaterThan(seaAnimals.count, 0, "Should have some sea animals")
    }

    // Test 6: filteredAnimals filters by search text
    func testFilteredAnimalsBySearchText() {
        let vm = AnimalPickerViewModel()
        vm.searchText = "shark"
        let results = vm.filteredAnimals
        XCTAssertTrue(results.allSatisfy { $0.name.lowercased().contains("shark") })
        XCTAssertGreaterThan(results.count, 0)
    }

    // Test 7: Cannot select same animal in both slots
    func testCannotSelectSameAnimalTwice() {
        let vm = AnimalPickerViewModel()
        let lion = Animals.all.first { $0.id == "lion" }!
        vm.select(lion)
        vm.select(lion) // Try to select lion again
        XCTAssertNil(vm.fighter2, "Should not be able to select the same animal in both slots")
    }

    // Test 8: Clear slot works correctly
    func testClearSlot() {
        let vm = AnimalPickerViewModel()
        let lion = Animals.all.first { $0.id == "lion" }!
        vm.select(lion)
        XCTAssertNotNil(vm.fighter1)
        vm.clear(1)
        XCTAssertNil(vm.fighter1)
    }

    // MARK: - Winner-picking on the phone (must agree with the server)

    private func animal(_ id: String) -> Animal { Animals.all.first { $0.id == id }! }

    // Every built-in creature has power data from the master list.
    func testOnDeviceTiersCoverTheWholeRoster() {
        for a in Animals.all {
            XCTAssertTrue(OnDeviceTiers.isBuiltIn(a.id), "\(a.id) is missing from OnDeviceTiers — run scripts/sync_creatures.mjs")
        }
    }

    // Same matchup, either order, any arena → the same winner every time.
    func testResolverIsDeterministicAndOrderIndependent() {
        let sample = stride(from: 0, to: Animals.all.count, by: 7).map { Animals.all[$0] }
        for env in BattleEnvironment.allCases {
            for arena in [true, false] {
                for a in sample {
                    for b in sample where a.id < b.id {
                        let v1 = OnDeviceResolver.resolve(a, b, environment: env, arenaEffectsEnabled: arena)
                        let v2 = OnDeviceResolver.resolve(b, a, environment: env, arenaEffectsEnabled: arena)
                        XCTAssertEqual(v1.winner.id, v2.winner.id, "\(a.id) vs \(b.id) in \(env)")
                    }
                }
            }
        }
    }

    // Spot checks shared with the server's test suite (backend/test/resolver.test.js).
    func testRealisticOutcomesMatchTheServer() {
        let cases: [(String, String, BattleEnvironment?, String)] = [
            ("tiger", "lion", nil, "tiger"),
            ("wolf", "great_dane", nil, "wolf"),
            ("goldfish", "horse", .ocean, "goldfish"),
            ("goldfish", "hamster", .grassland, "hamster"),
            ("parakeet", "tabby_cat", .sky, "parakeet"),
            ("dragon", "chicken", .sky, "dragon"),
            ("zeus", "ares", nil, "zeus"),
            ("zeus", "kronos", nil, "zeus"),
        ]
        for (a, b, env, expected) in cases {
            let v = OnDeviceResolver.resolve(animal(a), animal(b), environment: env ?? .grassland,
                                             arenaEffectsEnabled: env != nil)
            XCTAssertEqual(v.winner.id, expected, "\(a) vs \(b)")
        }
    }

    // The offline result names the same winner every time, with a real fact.
    func testOfflineFallbackIsDeterministic() async {
        let first = await BattleService.shared.generateFallbackResult(
            fighter1: animal("great_dane"), fighter2: animal("tabby_cat"), arenaEffectsEnabled: false)
        for _ in 0..<5 {
            let again = await BattleService.shared.generateFallbackResult(
                fighter1: animal("tabby_cat"), fighter2: animal("great_dane"), arenaEffectsEnabled: false)
            XCTAssertEqual(again.winner, first.winner)
        }
        XCTAssertEqual(first.winner, "great_dane")
        XCTAssertTrue(first.funFact.hasPrefix("Great Dane fact:"))
    }

    // Custom names: notorious people, hate groups and weapons never become a
    // fighter (real photos show for custom names); real animals still work.
    func testContentFilterBlocksNotoriousNamesButNotAnimals() {
        for bad in ["Hitler", "Nazi Wolf", "Osama Bin Laden", "Ku Klux Klan", "Ted Bundy", "AK-47", "Machine Gun", "Big Bomb"] {
            XCTAssertFalse(ContentFilter.isAppropriate(bad), bad)
        }
        for ok in ["Pistol Shrimp", "Knife Fish", "Isis", "Bundy the Bear", "Bombardier Beetle", "Gunnar", "Penguin"] {
            XCTAssertTrue(ContentFilter.isAppropriate(ok), ok)
        }
    }
}
