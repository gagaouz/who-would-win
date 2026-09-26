import SwiftUI
import CryptoKit
import ImageIO

// Semantic poses may share an authored idle frame; the native motion rig supplies movement.
enum RetroPose: String, CaseIterable { case idle, anticipation, attack, reaction }

struct RetroSpriteManifest: Decodable {
    struct Sprite: Decodable {
        let asset: String
        let archetype: String
        let frames: [String: [Int]]
    }
    let version: Int
    let styleVersion: String
    let sprites: [String: Sprite]
    let customBases: [String: Sprite]?
}

/// A local visual recipe, separate from the Animal's identity, stats and result.
/// Keyword matches are intentionally limited. Unknown names receive a fantasy
/// avatar; this is not an arbitrary character likeness or a semantic image model.
struct RetroCustomRecipe: Equatable {
    enum Source: Equatable { case catalog(String), base(String) }
    enum Tint: String, CaseIterable {
        case red, orange, yellow, green, blue, purple, pink, silver, white, black
        var rgb: (Double, Double, Double) {
            switch self {
            case .red: return (210, 76, 66)
            case .orange: return (222, 133, 64)
            case .yellow: return (229, 196, 93)
            case .green: return (104, 164, 103)
            case .blue: return (82, 139, 190)
            case .purple: return (156, 110, 182)
            case .pink: return (207, 132, 162)
            case .silver: return (153, 165, 177)
            case .white: return (232, 229, 213)
            case .black: return (70, 67, 81)
            }
        }
    }
    enum Ornament: String, CaseIterable { case none, sparkle, frost, leaf, bolt }
    static let baseIDs = ["robot", "knight", "wizard", "superhero", "slime", "mushroom", "tree", "alien", "wingedcat", "rockgolem", "seaserpent", "ghost"]

    let normalizedName: String
    let source: Source
    let tint: Tint?
    let explicitTint: Bool
    let ornament: Ornament
    let isFantasyAvatar: Bool

    static func normalize(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    private static func words(_ value: String) -> String {
        value.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
    }

    static func make(name: String, catalog: [Animal] = Animals.all) -> Self {
        let normalized = normalize(name)
        let phrase = " " + words(normalized) + " "
        let digest = Array(SHA256.hash(data: Data(("retro-local-v1|" + normalized).utf8)))
        func has(_ value: String) -> Bool { phrase.contains(" " + value + " ") }
        var matched = ""
        var source: Source?
        // These explicit composite shapes are more specific than "cat" or "tree".
        let composites = [("winged cat", "wingedcat"), ("flying cat", "wingedcat"),
                          ("rock golem", "rockgolem"), ("stone golem", "rockgolem"),
                          ("sea serpent", "seaserpent")]
        if let match = composites.first(where: { has($0.0) }) {
            matched = match.0; source = .base(match.1)
        }
        if source == nil {
            var candidates: [(phrase: String, id: String)] = []
            for animal in catalog where !animal.isCustom {
                candidates.append((phrase: words(normalize(animal.name)), id: animal.id))
                candidates.append((phrase: words(animal.id), id: animal.id))
            }
            candidates.sort { first, second in
                if first.phrase.count == second.phrase.count { return first.id < second.id }
                return first.phrase.count > second.phrase.count
            }
            if let match = candidates.first(where: { !$0.phrase.isEmpty && has($0.phrase) }) {
                matched = match.phrase; source = .catalog(match.id)
            }
        }
        if source == nil {
            let aliases = [("cat", "tabby_cat"), ("kitten", "tabby_cat"), ("dog", "labrador"),
                           ("puppy", "labrador"), ("rabbit", "pet_rabbit"), ("shark", "great_white_shark"),
                           ("eagle", "bald_eagle"), ("bear", "grizzly_bear"), ("snake", "cobra"),
                           ("dinosaur", "t_rex"), ("trex", "t_rex"), ("lioness", "lion"), ("wolves", "wolf")]
            if let match = aliases.first(where: { alias in has(alias.0) && catalog.contains(where: { $0.id == alias.1 }) }) {
                matched = match.0; source = .catalog(match.1)
            }
        }
        if source == nil, let id = baseIDs.first(where: { has($0) }) {
            matched = id; source = .base(id)
        }
        if source == nil {
            let bases = [("robot", "robot"), ("android", "robot"), ("knight", "knight"),
                         ("wizard", "wizard"), ("witch", "wizard"), ("superhero", "superhero"),
                         ("slime", "slime"), ("mushroom", "mushroom"), ("tree", "tree"),
                         ("alien", "alien"), ("golem", "rockgolem"), ("ghost", "ghost")]
            if let match = bases.first(where: { has($0.0) }) { matched = match.0; source = .base(match.1) }
        }
        let unknown = source == nil
        let resolved = source ?? .base(baseIDs[Int(digest[0]) % baseIDs.count])
        // "Great White Shark" / "Black Bear" keep their natural palette unless
        // a separate color modifier is present in the typed name.
        let modifiers = matched.isEmpty ? phrase : phrase.replacingOccurrences(of: " " + matched + " ", with: " ")
        let color = Tint.allCases.first { modifiers.contains(" " + $0.rawValue + " ") }
        let variantColors: [Tint] = [.green, .blue, .purple, .orange, .pink, .yellow]
        let ornament: Ornament
        if has("ice") || has("frost") || has("snow") { ornament = .frost }
        else if has("electric") || has("lightning") || has("robot") { ornament = .bolt }
        else if has("forest") || has("moss") || has("leaf") { ornament = .leaf }
        else if has("star") || has("magic") || has("cosmic") { ornament = .sparkle }
        else { ornament = unknown && digest[2].isMultiple(of: 2) ? .sparkle : .none }
        return Self(normalizedName: normalized, source: resolved,
                    tint: color ?? (unknown ? variantColors[Int(digest[1]) % variantColors.count] : nil),
                    explicitTint: color != nil, ornament: ornament, isFantasyAvatar: unknown)
    }
}

/// Deterministic decoded-atlas ownership. Unlike UIImage(named:), raw bundle
/// PNGs have no shared UIKit cache. Displayed crops are copied out of these images
/// before retention, so an evicted atlas cannot be pinned by a small portrait.
@MainActor
final class RetroAtlasCache {
    private struct Entry {
        let image: CGImage
        let cost: Int
        var access: UInt64
    }
    private var entries: [String: Entry] = [:]
    private var clock: UInt64 = 0
    private let loader: (String) -> CGImage?
    let costLimit: Int
    private(set) var residentCost = 0
    var cachedNames: Set<String> { Set(entries.keys) }

    init(costLimit: Int = 32 * 1024 * 1024, loader: @escaping (String) -> CGImage?) {
        self.costLimit = max(0, costLimit)
        self.loader = loader
    }

    func image(named name: String) -> CGImage? {
        clock &+= 1
        if var entry = entries[name] {
            entry.access = clock; entries[name] = entry
            return entry.image
        }
        guard let image = loader(name) else { return nil }
        let cost = image.bytesPerRow * image.height
        // An oversized optional sheet can still produce a detached crop, but it
        // is never retained beyond the call or allowed to exceed the cache budget.
        guard cost > 0, cost <= costLimit else { return image }
        while residentCost + cost > costLimit,
              let oldest = entries.min(by: { $0.value.access < $1.value.access }) {
            residentCost -= oldest.value.cost
            entries.removeValue(forKey: oldest.key)
        }
        entries[name] = Entry(image: image, cost: cost, access: clock)
        residentCost += cost
        return image
    }

    func removeAll() { entries.removeAll(); residentCost = 0; clock = 0 }

    /// A URL resolver is injectable so tests exercise the actual ImageIO loader,
    /// including precedence over the legacy catalog and missing-file behavior.
    static func load(named name: String, rawURL: (String) -> URL?, legacy: (String) -> CGImage?) -> CGImage? {
        if let url = rawURL(name) {
            let options = [kCGImageSourceShouldCache: false,
                           kCGImageSourceShouldAllowFloat: false] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
            // Materialize RGBA once, outside ImageIO's implicit decoded caches.
            return detachedCopy(of: image)
        }
        // Kept only for the existing asset-catalog packs during migration.
        return legacy(name)
    }

    static func detachedCopy(of source: CGImage, crop: CGRect? = nil) -> CGImage? {
        let image: CGImage
        if let crop {
            guard CGRect(x: 0, y: 0, width: source.width, height: source.height).contains(crop),
                  let region = source.cropping(to: crop) else { return nil }
            image = region
        } else { image = source }
        // Bundle artwork is 8-bit pixel art. An explicit tightly packed RGBA
        // buffer gives the cache honest costs and prevents parent-atlas retention.
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}

/// Every catalog and custom image is local. No description leaves the device,
/// and no asynchronous task can hold up a battle or survive a cache clear.
@MainActor
final class RetroAssetStore: ObservableObject {
    static let shared = RetroAssetStore()
    nonisolated static let styleVersion = "retro-v1"
    @Published private(set) var revision = 0
    let manifest: RetroSpriteManifest?
    private let images = NSCache<NSString, UIImage>()
    private let atlases: RetroAtlasCache
    private var memoryWarningObserver: NSObjectProtocol?

    private convenience init() {
        let manifest = Bundle.main.url(forResource: "RetroSpriteManifest", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(RetroSpriteManifest.self, from: $0) }
        self.init(manifest: manifest)
    }

    /// The injected loader is used by cache/lifecycle tests; production resolves
    /// raw folder resources first and the original asset catalog second.
    init(manifest: RetroSpriteManifest?, atlasCostLimit: Int = 32 * 1024 * 1024,
         atlasLoader: ((String) -> CGImage?)? = nil) {
        self.manifest = manifest
        atlases = RetroAtlasCache(costLimit: atlasCostLimit, loader: atlasLoader ?? { name in
            RetroAtlasCache.load(named: name, rawURL: {
                Bundle.main.url(forResource: $0, withExtension: "png", subdirectory: "RetroAtlases")
            }, legacy: { UIImage(named: $0)?.cgImage })
        })
        images.totalCostLimit = 32 * 1024 * 1024
        images.countLimit = 220
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Existing views keep their detached images. Do not publish an
                // art revision here and immediately recreate all scene textures.
                self?.images.removeAllObjects()
                self?.atlases.removeAll()
            }
        }
    }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(memoryWarningObserver) }
    }

    func atlasImage(named name: String) -> CGImage? { atlases.image(named: name) }
    var cachedAtlasCost: Int { atlases.residentCost }

    nonisolated static func customCacheKey(for name: String) -> String {
        SHA256.hash(data: Data(("retro-local-v1|" + RetroCustomRecipe.normalize(name)).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    func image(for animal: Animal, pose: RetroPose = .idle) -> UIImage? {
        let key = animal.isCustom ? "\(Self.customCacheKey(for: animal.name)).\(pose.rawValue)" : "\(animal.id).\(pose.rawValue)"
        if let image = images.object(forKey: key as NSString) { return image }
        let image: UIImage?
        if animal.isCustom {
            let recipe = RetroCustomRecipe.make(name: animal.name)
            let sprite: RetroSpriteManifest.Sprite?
            switch recipe.source {
            case .catalog(let id): sprite = manifest?.sprites[id]
            case .base(let id): sprite = manifest?.customBases?[id]
            }
            let source = cropped(sprite, pose: pose)
            // Every pose uses one scale and one foot baseline. Fitting each pose
            // independently makes an extended attack visibly shrink its body.
            let familyExtent = sprite?.frames.values.compactMap { frame -> Int? in
                guard frame.count == 4 else { return nil }
                return max(frame[2], frame[3])
            }.max().map { CGFloat($0) }
            image = RetroLocalAvatarRenderer.render(recipe: recipe, source: source, familyExtent: familyExtent)
        } else { image = cropped(manifest?.sprites[animal.id], pose: pose) }
        guard let image else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
        images.setObject(image, forKey: key as NSString, cost: cost)
        return image
    }

    private func cropped(_ sprite: RetroSpriteManifest.Sprite?, pose: RetroPose) -> UIImage? {
        guard let sprite, let values = sprite.frames[pose.rawValue] ?? sprite.frames[RetroPose.idle.rawValue],
              values.count == 4, values.allSatisfy({ $0 >= 0 }), values[2] > 0, values[3] > 0,
              let sheet = atlasImage(named: sprite.asset) else { return nil }
        let rect = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        guard CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height).contains(rect),
              let cropped = RetroAtlasCache.detachedCopy(of: sheet, crop: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }

    func archetype(for animal: Animal) -> String? {
        guard animal.isCustom else { return manifest?.sprites[animal.id]?.archetype }
        switch RetroCustomRecipe.make(name: animal.name).source {
        case .catalog(let id): return manifest?.sprites[id]?.archetype
        case .base(let id): return manifest?.customBases?[id]?.archetype
        }
    }

    func artworkDescription(for animal: Animal) -> String {
        guard animal.isCustom else { return "" }
        let recipe = RetroCustomRecipe.make(name: animal.name)
        if recipe.isFantasyAvatar { return "Fantasy avatar made on this device" }
        switch recipe.source {
        case .catalog(let id):
            return "Local sprite based on \(Animals.all.first(where: { $0.id == id })?.name ?? "a creature")"
        case .base: return "Fantasy sprite made on this device"
        }
    }

    // Kept async to preserve the shared stage interface; preparation is immediate.
    func prepare(_ animals: [Animal]) async { for animal in animals { _ = image(for: animal) } }
    func prepare(_ animal: Animal, retry: Bool = false) async { _ = image(for: animal) }

    /// Parent erase flow can synchronously discard the bounded memory cache.
    func clearMemoryCache() {
        images.removeAllObjects()
        atlases.removeAll()
        revision &+= 1
    }
}

/// Nearest-neighbor native rendering, with light palette changes that retain
/// source luminance, dark outlines and highlights. Decorations are original
/// pixel geometry; they never alter creature identity, attributes or outcomes.
@MainActor
private enum RetroLocalAvatarRenderer {
    static func render(recipe: RetroCustomRecipe, source: UIImage?, familyExtent: CGFloat?) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let canvas = CGSize(width: 128, height: 128)
        let base = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            let c = renderer.cgContext
            c.interpolationQuality = .none; c.setAllowsAntialiasing(false)
            if let source {
                let scale = 116 / max(familyExtent ?? max(source.size.width, source.size.height), 1)
                let size = CGSize(width: (source.size.width * scale).rounded(), height: (source.size.height * scale).rounded())
                source.draw(in: CGRect(x: ((128 - size.width) / 2).rounded(), y: 122 - size.height, width: size.width, height: size.height))
            } else {
                // A guaranteed local fallback if a future optional base pack is missing.
                let outline = UIColor(red: 0.19, green: 0.18, blue: 0.25, alpha: 1)
                outline.setFill()
                for r in [CGRect(x: 30, y: 42, width: 70, height: 66), CGRect(x: 40, y: 30, width: 50, height: 80), CGRect(x: 34, y: 103, width: 19, height: 18), CGRect(x: 78, y: 103, width: 18, height: 18)] { c.fill(r) }
                UIColor(red: 0.50, green: 0.68, blue: 0.51, alpha: 1).setFill()
                c.fill(CGRect(x: 36, y: 48, width: 58, height: 54)); c.fill(CGRect(x: 46, y: 36, width: 38, height: 20))
                UIColor(red: 0.88, green: 0.92, blue: 0.71, alpha: 1).setFill()
                c.fill(CGRect(x: 64, y: 55, width: 11, height: 12)); c.fill(CGRect(x: 82, y: 55, width: 9, height: 12))
                outline.setFill(); c.fill(CGRect(x: 69, y: 57, width: 5, height: 8)); c.fill(CGRect(x: 86, y: 57, width: 4, height: 8))
            }
        }
        let tinted = recolor(base, recipe: recipe)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            let c = renderer.cgContext; c.setAllowsAntialiasing(false); c.interpolationQuality = .none
            tinted.draw(at: .zero)
            func block(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UIColor) {
                color.setFill(); c.fill(CGRect(x: x, y: y, width: w, height: h))
            }
            let warm = UIColor(red: 0.95, green: 0.79, blue: 0.39, alpha: 1)
            let cool = UIColor(red: 0.66, green: 0.87, blue: 0.88, alpha: 1)
            switch recipe.ornament {
            case .none: break
            case .sparkle:
                block(10, 26, 14, 4, warm); block(15, 21, 4, 14, warm)
                block(108, 40, 8, 3, warm); block(111, 37, 3, 9, warm)
            case .frost:
                block(9, 28, 14, 3, cool); block(14, 23, 3, 14, cool)
                block(11, 24, 3, 3, cool); block(19, 34, 3, 3, cool)
            case .leaf:
                block(12, 24, 8, 4, UIColor(red: 0.43, green: 0.64, blue: 0.36, alpha: 1))
                block(9, 28, 8, 4, UIColor(red: 0.55, green: 0.73, blue: 0.43, alpha: 1))
            case .bolt:
                block(17, 18, 7, 8, warm); block(12, 26, 9, 5, warm); block(10, 31, 6, 8, warm)
            }
        }
    }

    private static func recolor(_ image: UIImage, recipe: RetroCustomRecipe) -> UIImage {
        guard let tint = recipe.tint, let source = image.cgImage else { return image }
        let width = source.width, height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        return bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return image }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let values = raw.bindMemory(to: UInt8.self)
            let (tr, tg, tb) = tint.rgb
            let targetLuminance = (tr * 0.2126 + tg * 0.7152 + tb * 0.0722)
            let strength = recipe.explicitTint ? 0.62 : 0.18
            for i in stride(from: 0, to: values.count, by: 4) where values[i + 3] > 220 {
                let r = Double(values[i]), g = Double(values[i + 1]), b = Double(values[i + 2])
                let luminance = r * 0.2126 + g * 0.7152 + b * 0.0722
                guard luminance > 43, luminance < 229 else { continue }
                var level = luminance
                if tint == .black { level *= 0.65 }
                if tint == .white { level = min(238, level * 1.28 + 18) }
                let factor = level / max(1, targetLuminance)
                for (channel, original, target) in [(0, r, tr), (1, g, tg), (2, b, tb)] {
                    values[i + channel] = UInt8(max(0, min(255, original * (1 - strength) + min(255, target * factor) * strength)).rounded())
                }
            }
            guard let result = context.makeImage() else { return image }
            return UIImage(cgImage: result)
        }
    }
}
