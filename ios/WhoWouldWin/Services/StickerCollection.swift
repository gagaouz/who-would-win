import Foundation
import Combine

/// Tracks which animals the player has battled with — that's how stickers are
/// "collected" for the Sticker Book. Every time a battle starts, both fighters
/// get added to the set. The set is persisted in UserDefaults and observable
/// so the Sticker Book updates live.
@MainActor
final class StickerCollection: ObservableObject {

    static let shared = StickerCollection()

    private let key = "collected.animals"
    private let ud = UserDefaults.standard

    @Published private(set) var collected: Set<String> = []
    /// Most recently collected animal ID — useful for "new sticker!" UI.
    @Published var lastUnlocked: String? = nil

    private init() {
        let arr = ud.stringArray(forKey: key) ?? []
        collected = Set(arr)
    }

    /// Add an animal to the sticker book. Returns true if it was newly added.
    @discardableResult
    func collect(_ animal: Animal) -> Bool {
        let id = animal.id
        guard !collected.contains(id) else { return false }
        collected.insert(id)
        ud.set(Array(collected), forKey: key)
        lastUnlocked = id
        return true
    }

    /// Add a batch — used at end of battle so both fighters get logged.
    /// Returns the count of NEW stickers added.
    @discardableResult
    func collectBoth(_ a: Animal, _ b: Animal) -> Int {
        var newCount = 0
        if collect(a) { newCount += 1 }
        if collect(b) { newCount += 1 }
        return newCount
    }

    func has(_ id: String) -> Bool { collected.contains(id) }

    var count: Int { collected.count }

    /// Wipe the whole collection (backs the "erase all data" path).
    func eraseAll() {
        collected.removeAll()
        lastUnlocked = nil
        ud.removeObject(forKey: key)
    }
}
