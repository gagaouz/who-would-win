import XCTest
@testable import WhoWouldWin

final class BattleServiceTests: XCTestCase {

    // Test 1: All 50 animals exist and have valid IDs
    func testAllAnimalIDsAreValid() {
        XCTAssertEqual(Animals.all.count, 50, "Should have exactly 50 animals")
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
}
