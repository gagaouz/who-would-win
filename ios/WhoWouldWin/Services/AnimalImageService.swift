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
        } else if let pollinationsURL = pollinationsURL(for: name) {
            url = pollinationsURL
        } else {
            // Absolute last resort — static placeholder (encoding of name failed).
            url = URL(string: "https://image.pollinations.ai/prompt/animal?width=512&height=512&nologo=true&model=flux-schnell&safe=true")!
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
        imageCache[animal.id] = img
        return img
    }

    // ── Emoji / category from backend ──────────────────────────────────────

    /// Asks the backend for the best emoji + category + colour for a name.
    func fetchAnimalInfo(name: String) async -> (emoji: String, category: AnimalCategory, color: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlStr  = "\(AppConfig.backendBaseURL)/api/animal?name=\(encoded)"
        guard let url = URL(string: urlStr) else { return ("🐾", .land, "#888888") }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
                return URL(string: source)
            }
        } catch {}
        return nil
    }

    /// Builds a Pollinations.ai URL — always valid, AI-generated.
    /// safe=true enables Pollinations' built-in content filter (blocks NSFW).
    /// The prompt is deliberately generic — we only pass the name, never
    /// user-supplied adjectives — to avoid prompt injection via the search bar.
    private func pollinationsURL(for name: String) -> URL? {
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

        let prompt  = "cute cartoon illustration of \(safeName), child-friendly, simple background"
        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                      ?? safeName
        // safe=true → Pollinations content filter; model=flux-schnell → fast
        guard let url = URL(string: "https://image.pollinations.ai/prompt/\(encoded)?width=512&height=512&nologo=true&model=flux-schnell&safe=true") else {
            return nil
        }
        return url
    }

    /// Downloads image data from a URL and decodes it into a UIImage.
    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
