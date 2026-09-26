import SwiftUI

// MARK: - Sticker Book — Animal Arena Jr.
// Battle a creature and it joins your sticker book. Locked packs still appear
// as teaser sections so kids can see what's coming.

struct KidsStickerBookView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var cheat = CheatState.shared
    @ObservedObject private var collection = StickerCollection.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    @State private var appeared = false
    @State private var lockedSheet: AnimalCategory? = nil
    /// A collected creature whose durable facts are being shown.
    @State private var factsAnimal: Animal? = nil

    // Excludes Olympus from the visible book unless the cheat has been revealed.
    private var visibleAnimals: [Animal] {
        Animals.all.filter { animal in
            animal.category != .olympus
                || cheat.olympusUnlocked
                || settings.isOlympusVisible
        }
    }
    private var collectedIDs: Set<String> { collection.collected }
    private var collectedCount: Int {
        visibleAnimals.filter { collectedIDs.contains($0.id) }.count
    }
    private var totalCount: Int { visibleAnimals.count }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(collectedCount) / Double(totalCount)
    }

    var body: some View {
        ZStack {
            SkyBG()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
                        header
                        progressCard

                        // Always-available packs
                        section(title: "Land Critters",  emoji: "🌳", color: Kids.grass,
                                category: .land)
                        section(title: "Ocean Pals",     emoji: "🌊", color: Kids.sky,
                                category: .sea)
                        section(title: "Sky Friends",    emoji: "☁️", color: Kids.grape,
                                category: .air)
                        section(title: "Little Buddies", emoji: "🐛", color: Kids.peach,
                                category: .insect)
                        section(title: "Pet Pals",       emoji: "🐶", color: Kids.peach,
                                category: .pets)
                        section(title: "Farm Friends",   emoji: "🚜", color: Kids.grass,
                                category: .farm)

                        // Pack-gated sections — show always, lock the contents.
                        section(title: "Dino Pals",       emoji: "🦖", color: Kids.sun,
                                category: .prehistoric, lockedIfMissing: true)
                        section(title: "Fantasy Friends", emoji: "🧚", color: Kids.grape,
                                category: .fantasy,     lockedIfMissing: true)
                        section(title: "Mythic Legends",  emoji: "⚡",  color: Kids.sunDeep,
                                category: .mythic,      lockedIfMissing: true)
                        if cheat.olympusUnlocked || settings.isOlympusVisible {
                            section(title: "Olympus Gods", emoji: "🔱", color: Kids.sunDeep,
                                    category: .olympus, lockedIfMissing: true)
                        }

                        Spacer(minLength: 30)
                    }
                    .frame(maxWidth: isIPad ? 760 : .infinity)
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
        .sheet(item: $lockedSheet) { cat in
            switch cat {
            case .fantasy:     FantasyUnlockSheet(isPresented: bindingForSheet)
            case .prehistoric: PrehistoricUnlockSheet(isPresented: bindingForSheet)
            case .mythic:      MythicUnlockSheet(isPresented: bindingForSheet)
            case .olympus:     OlympusUnlockSheet(isPresented: bindingForSheet)
            default:           EmptyView()
            }
        }
        .sheet(item: $factsAnimal) { a in
            AnimalFactsSheet(animal: a)
        }
    }

    private var bindingForSheet: Binding<Bool> {
        Binding(
            get: { lockedSheet != nil },
            set: { if !$0 { lockedSheet = nil } }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            KidIconBtn(icon: "←", fill: .white) { dismiss() }
            Spacer()
            Text("MY STICKER BOOK")
                .font(Kids.fredoka(isIPad ? 24 : 18, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, isIPad ? 20 : 16)
        .padding(.top, isIPad ? 12 : 8)
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 14 : 10) {
            HStack(spacing: isIPad ? 14 : 10) {
                RetroSymbol("🏆", size: isIPad ? 40 : 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(collectedCount) of \(totalCount) collected")
                        .font(Kids.fredoka(isIPad ? 19 : 15, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(percentBlurb)
                        .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
            }
            BookProgressBar(progress: progress)
                .frame(height: isIPad ? 16 : 12)
        }
        .padding(isIPad ? 18 : 14)
        .frame(maxWidth: .infinity)
        .background(
            RetroPanelShape(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
        .padding(.horizontal, isIPad ? 20 : 16)
    }

    private var percentBlurb: String {
        let pct = Int((progress * 100).rounded())
        if pct == 0 { return "Battle to collect your first sticker!" }
        if pct >= 100 { return "All stickers collected!" }
        return "\(pct)% complete — keep going!"
    }

    // MARK: - Section

    @ViewBuilder
    private func section(title: String, emoji: String, color: Color,
                         category: AnimalCategory,
                         lockedIfMissing: Bool = false) -> some View {
        let isUnlocked = isCategoryUnlocked(category)
        let displayLocked = lockedIfMissing && !isUnlocked
        let pool = Animals.all.filter { $0.category == category }
        if !pool.isEmpty {
            VStack(alignment: .leading, spacing: isIPad ? 14 : 10) {
                HStack(spacing: isIPad ? 8 : 6) {
                    RetroSymbol(emoji, size: isIPad ? 20 : 16)
                    Text(title)
                        .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                        .foregroundColor(Kids.ink)
                    if displayLocked {
                        RetroSymbol("🔒", size: isIPad ? 15 : 12)
                    }
                    Spacer(minLength: 8)
                    if displayLocked {
                        Button {
                            lockedSheet = category
                        } label: {
                            Text("Unlock")
                                .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .padding(.horizontal, isIPad ? 14 : 10).padding(.vertical, isIPad ? 6 : 4)
                                .background(
                                    RetroPanelShape().fill(Kids.sun)
                                        .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, isIPad ? 20 : 16)
                    } else {
                        let owned = pool.filter { collectedIDs.contains($0.id) }.count
                        Text("\(owned)/\(pool.count)")
                            .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .padding(.trailing, isIPad ? 20 : 16)
                    }
                }
                .padding(.horizontal, isIPad ? 20 : 16)
                .opacity(displayLocked ? 0.7 : 1)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isIPad ? 14 : 10) {
                        ForEach(pool, id: \.id) { a in
                            StickerTile(
                                animal: a,
                                collected: collectedIDs.contains(a.id),
                                lockedPack: displayLocked,
                                isIPad: isIPad
                            )
                            .onTapGesture {
                                HapticsService.shared.tap()
                                if displayLocked {
                                    lockedSheet = category
                                } else if collectedIDs.contains(a.id) {
                                    // Tap a sticker you own to read its real facts.
                                    factsAnimal = a
                                }
                            }
                        }
                    }
                    .padding(.horizontal, isIPad ? 20 : 16)
                }
            }
        }
    }

    private func isCategoryUnlocked(_ c: AnimalCategory) -> Bool {
        switch c {
        case .fantasy:     return settings.isFantasyUnlocked
        case .prehistoric: return settings.isPrehistoricUnlocked
        case .mythic:      return settings.isMythicUnlocked
        case .olympus:     return settings.isOlympusUnlocked || cheat.olympusUnlocked
        default:           return true
        }
    }
}

// MARK: - Progress bar (slim, low-chrome — same look as Home counter chips)

private struct BookProgressBar: View {
    var progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RetroPanelShape().fill(Kids.creamDeep)
                RetroPanelShape()
                    .fill(Kids.grassDeep)
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, progress)))))
            }
            .clipShape(RetroPanelShape())
            .overlay(RetroPanelShape().stroke(Kids.ink.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - Sticker tile

private struct StickerTile: View {
    let animal: Animal
    let collected: Bool
    let lockedPack: Bool
    var isIPad: Bool = false

    var body: some View {
        let tileSize: CGFloat = isIPad ? 80 : 64
        let innerSize: CGFloat = isIPad ? 66 : 52
        VStack(spacing: isIPad ? 6 : 4) {
            ZStack {
                RetroPanelShape(cornerRadius: 16, style: .continuous)
                    .fill(collected ? .white : (lockedPack ? Kids.creamDeep : Color.white.opacity(0.5)))
                    .overlay(
                        RetroPanelShape(cornerRadius: 16, style: .continuous)
                            .stroke(
                                collected ? Kids.ink : Kids.ink.opacity(lockedPack ? 0.3 : 0.35),
                                style: StrokeStyle(
                                    lineWidth: collected ? 3 : 2,
                                    dash: collected ? [] : (lockedPack ? [] : [5, 3])
                                )
                            )
                    )
                    .frame(width: tileSize, height: tileSize)

                if collected {
                    RetroCreatureArtwork(animal: animal, size: innerSize)
                } else if lockedPack {
                    RetroSymbol("🔒", size: isIPad ? 28 : 22)
                        .opacity(0.6)
                } else {
                    Text("?")
                        .font(.system(size: isIPad ? 34 : 28))
                        .foregroundColor(Kids.inkSoft.opacity(0.5))
                }
            }
            Text(collected ? animal.name : (lockedPack ? "Locked" : "???"))
                .font(Kids.fredoka(isIPad ? 12 : 10, weight: .bold))
                .foregroundColor(collected ? Kids.ink : Kids.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: tileSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(collected ? animal.name : (lockedPack ? "Locked creature" : "Uncollected creature"))
        .accessibilityValue(collected ? "Collected" : "")
    }
}

// MARK: - AnimalCategory: Identifiable conformance so it can drive sheet(item:)

extension AnimalCategory: Identifiable {
    public var id: String { rawValue }
}
