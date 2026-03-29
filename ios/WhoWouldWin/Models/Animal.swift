import Foundation

struct Animal: Identifiable, Hashable, Sendable {
    let id: String          // snake_case, e.g. "lion"
    let name: String        // Display name, e.g. "Lion"
    let emoji: String       // Single emoji
    let category: AnimalCategory
    let pixelColor: String  // Hex color string, e.g. "#8B4513"
    let size: Int           // 1–5, used for sprite scaling
    let isCustom: Bool      // true for user-typed free-text animals
    let imageURL: URL?      // real photo URL for custom animals (Wikipedia / Pollinations)

    init(id: String, name: String, emoji: String, category: AnimalCategory, pixelColor: String, size: Int, isCustom: Bool = false, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.pixelColor = pixelColor
        self.size = size
        self.isCustom = isCustom
        self.imageURL = imageURL
    }
}

enum AnimalCategory: String, CaseIterable, Sendable {
    case all = "ALL"
    case land = "LAND"
    case sea = "SEA"
    case air = "AIR"
    case insect = "BUGS"
}
