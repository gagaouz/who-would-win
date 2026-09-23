import UIKit

/// Fetches and caches images for custom fighters.
///
/// Priority order for image lookup:
///   1. Wikipedia REST API  — real photos, fast (~200 ms), works for anything famous
///      (animals, people, places, bands, movies, …)
///   2. Pollinations.ai     — AI-generated fallback, always returns an image
///
/// Both the resolved URL (for SwiftUI AsyncImage in the picker) and the
/// downloaded UIImage (for SpriteKit sprites in the battle scene) are cached.
actor AnimalImageService {
    static let shared = AnimalImageService()
    private init() {}

    // MARK: - Caches

    /// Animal id → downloaded UIImage (for SpriteKit sprites)
    private var imageCache:  [String: UIImage] = [:]
    /// Animal name (lowercased) → resolved image URL (for SwiftUI AsyncImage)
    private var urlCache:    [String: URL]     = [:]
    private let maxImageBytes = 5 * 1024 * 1024
    /// Hosts Wikipedia serves article photos from. Wikipedia moved thumbnails
    /// from upload.wikimedia.org to thumb.wikimedia.org in 2026; accepting only
    /// the old host silently rejected EVERY real photo, so every custom
    /// creature fell back to the slow AI cartoon (or a blank placeholder).
    static let wikipediaImageHosts: Set<String> = ["upload.wikimedia.org", "thumb.wikimedia.org"]
    private let maxCachedImages = 100
    private let maxCachedURLs = 200

    // MARK: - Public API

    // ── URL for SwiftUI AsyncImage ──────────────────────────────────────────

    /// Returns the best available image URL for a display name.
    /// Tries Wikipedia first; falls back to a Pollinations.ai URL.
    /// The result is cached so repeat calls are instant.
    func imageURL(for name: String) async -> URL {
        let key = name.lowercased()
        if let cached = urlCache[key] { return cached }

        // Wikipedia first, then Pollinations. Both can theoretically return nil
        // (Pollinations only if URL encoding fails, which is extremely unlikely).
        // Fall back to a guaranteed-valid placeholder URL so callers always get a URL.
        let url: URL
        if let wikiURL = await wikipediaImageURL(for: name) {
            url = wikiURL
        } else if Task.isCancelled {
            // The Wikipedia lookup was abandoned mid-flight (the calling view
            // disappeared or changed identity) — it didn't really fail. Serve
            // the fallback to THIS caller but do NOT cache it, otherwise the
            // creature is stuck showing an AI cartoon instead of its real
            // photo for the rest of the session.
            return pollinationsURL(for: name)
                ?? URL(string: "https://image.pollinations.ai/prompt/animal?width=512&height=512&nologo=true&model=flux-schnell&safe=true")!
        } else if let pollinationsURL = pollinationsURL(for: name) {
            url = pollinationsURL
        } else {
            // Absolute last resort — static placeholder (encoding of name failed).
            url = URL(string: "https://image.pollinations.ai/prompt/animal?width=512&height=512&nologo=true&model=flux-schnell&safe=true")!
        }
        if urlCache.count >= maxCachedURLs, let oldest = urlCache.keys.first {
            urlCache.removeValue(forKey: oldest)
        }
        urlCache[key] = url
        return url
    }

    // ── UIImage for SpriteKit ───────────────────────────────────────────────

    /// Downloads and caches the best image for a custom animal.
    /// Returns nil for built-in (non-custom) animals so callers can fall back to emoji.
    func image(for animal: Animal) async -> UIImage? {
        guard animal.isCustom else { return nil }

        if let cached = imageCache[animal.id] { return cached }

        let url = await imageURL(for: animal.name)
        guard let img = await downloadImage(from: url) else { return nil }
        if imageCache.count >= maxCachedImages, let oldest = imageCache.keys.first {
            imageCache.removeValue(forKey: oldest)
        }
        imageCache[animal.id] = img
        return img
    }

    // ── Emoji / category from backend ──────────────────────────────────────

    /// Asks the backend for the best emoji + category + colour for a name.
    func fetchAnimalInfo(name: String) async -> (emoji: String, category: AnimalCategory, color: String) {
        guard let url = URL(string: "\(AppConfig.backendBaseURL)/api/animal") else {
            return ("🐾", .land, "#888888")
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            AnonymousRequestIdentity.apply(to: &request)
            let prepared = await AppAttestManager.shared.prepare(["name": name])
            request.httpBody = prepared.data
            if let authentication = prepared.authentication {
                request.setValue(authentication, forHTTPHeaderField: "X-App-Attest")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode), data.count <= 16_384 else {
                return ("🐾", .land, "#888888")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                let emojiStr = json["emoji"] ?? "🐾"
                let catStr   = json["category"] ?? "land"
                let color    = json["color"] ?? "#888888"
                let cat: AnimalCategory
                switch catStr {
                case "sea":    cat = .sea
                case "air":    cat = .air
                case "insect": cat = .insect
                default:       cat = .land
                }
                return (emojiStr, cat, color)
            }
        } catch {}
        return ("🐾", .land, "#888888")
    }

    // MARK: - Private helpers

    /// Calls the Wikipedia REST summary endpoint and extracts the thumbnail URL.
    /// Returns nil if the article doesn't exist or has no thumbnail.
    private func wikipediaImageURL(for name: String) async -> URL? {
        // Wikipedia uses title-cased article names; replace spaces with underscores
        let title   = name.trimmingCharacters(in: .whitespaces)
                          .components(separatedBy: " ")
                          .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                          .joined(separator: "_")
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else { return nil }

        do {
            var request    = URLRequest(url: url)
            request.timeoutInterval = 4   // fail fast so battle screen isn't blocked
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }

            if let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let thumbnail = json["thumbnail"]  as? [String: Any],
               let source    = thumbnail["source"] as? String {
                guard let result = URL(string: source),
                      result.scheme == "https",
                      let host = result.host?.lowercased(),
                      Self.wikipediaImageHosts.contains(host) else { return nil }
                return result
            }
        } catch {}
        return nil
    }

    /// Builds a Pollinations.ai URL — always valid, AI-generated.
    /// safe=true enables Pollinations' built-in content filter (blocks NSFW).
    /// The prompt is deliberately generic — we only pass the name, never
    /// user-supplied adjectives — to avoid prompt injection via the search bar.
    private func pollinationsURL(for name: String) -> URL? {
        // Defense-in-depth for a Kids app: never request an AI image for a name
        // our own content filter doesn't consider appropriate. (The custom-
        // creature flow already gates on ContentFilter upstream; this guards any
        // other caller and any future code path so a questionable name can never
        // reach the image generator.) On a fail, callers fall back to the emoji.
        guard ContentFilter.isAppropriate(name) else { return nil }

        // Sanitise: keep only letters, numbers, spaces and common punctuation.
        // This prevents a user-typed "naked X" from leaking adjectives into the prompt.
        let safeName = name
            .components(separatedBy: .whitespacesAndNewlines)
            .map { word in
                word.unicodeScalars.filter { CharacterSet.letters.union(.decimalDigits).contains($0) }
                    .map { String($0) }.joined()
            }
            .filter { !$0.isEmpty }
            .prefix(4)                // at most 4 words — no essays
            .joined(separator: " ")

        let prompt  = "cute wholesome G-rated cartoon illustration of \(safeName) as a friendly animal character, child-friendly, no text, no people, simple background"
        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                      ?? safeName
        // safe=true → Pollinations content filter; model=flux-schnell → fast
        guard let url = URL(string: "https://image.pollinations.ai/prompt/\(encoded)?width=512&height=512&nologo=true&model=flux-schnell&safe=true") else {
            return nil
        }
        return url
    }

    /// Downloads image data from a URL and decodes it into a UIImage.
    /// 12-second timeout — Pollinations.ai can be slow for AI-generated images,
    /// but we don't want to block the battle intro screen indefinitely.
    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let allowedHosts = Self.wikipediaImageHosts.union(["image.pollinations.ai"])
            guard url.scheme == "https", let host = url.host?.lowercased(),
                  allowedHosts.contains(host) else { return nil }
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  http.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("image/") == true,
                  data.count <= maxImageBytes,
                  let image = UIImage(data: data) else { return nil }
            if let cgImage = image.cgImage,
               cgImage.width * cgImage.height > 16_000_000 { return nil }
            return image
        } catch {
            return nil
        }
    }
}
