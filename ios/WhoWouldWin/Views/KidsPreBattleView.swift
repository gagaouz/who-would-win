import SwiftUI

// MARK: - Pre-Battle Arena Picker — Animal Arena Jr.
// Matches screenshots/03_prebattle.png — "PICK YOUR ARENA!"

struct KidsPreBattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    @Binding var selectedEnvironment: BattleEnvironment
    @Binding var arenaEffectsEnabled: Bool
    @Binding var isPresented: Bool
    var onStart: () -> Void

    @ObservedObject private var settings = UserSettings.shared
    @State private var appeared = false

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            SkyBG()

            VStack(spacing: 0) {
                // Handle
                RetroPanelShape().fill(Color.white.opacity(0.4))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 14) {
                        // Title
                        Text("PICK YOUR ARENA!")
                            .font(Kids.fredoka(24, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .padding(.top, 10)
                        Text("The place changes who has the edge")
                            .font(Kids.nunito(12, weight: .bold))
                            .foregroundColor(Kids.inkSoft)

                        // Matchup row
                        HStack(spacing: 14) {
                            AnimalBubble(animal: fighter1, size: 64, tint: Kids.sun, tilt: -4)
                            StarSticker(text: "VS", size: 40, fill: Kids.pink)
                            AnimalBubble(animal: fighter2, size: 64, tint: Kids.peach, tilt: 4)
                        }
                        .padding(.vertical, 4)

                        // Arena grid
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(BattleEnvironment.allCases, id: \.self) { env in
                                ArenaTile(
                                    env: env,
                                    selected: selectedEnvironment == env,
                                    locked: isLocked(env),
                                    isNew: isNew(env)
                                )
                                .onTapGesture {
                                    guard !isLocked(env) else { return }
                                    HapticsService.shared.tap()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        selectedEnvironment = env
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 14)

                        // Arena effects toggle
                        HStack(spacing: 10) {
                            RetroSymbol("✨", size: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Arena Effects")
                                    .font(Kids.fredoka(15, weight: .bold))
                                    .foregroundColor(Kids.ink)
                                Text("Rain, sparkles, wind & more!")
                                    .font(Kids.nunito(11, weight: .bold))
                                    .foregroundColor(Kids.inkSoft)
                            }
                            Spacer()
                            KidToggle(isOn: $arenaEffectsEnabled)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            RetroPanelShape(cornerRadius: 18, style: .continuous)
                                .fill(Kids.panel)
                                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                        )
                        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
                        .padding(.horizontal, 16)

                        // Go button
                        KidButton(title: "LET'S GO!", icon: "⚡", color: Kids.grass, size: .lg) {
                            HapticsService.shared.tap()
                            onStart()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                    }
                    .scaleEffect(appeared ? 1 : 0.95)
                    .opacity(appeared ? 1 : 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private func isLocked(_ env: BattleEnvironment) -> Bool {
        // Use the single canonical gate — it accounts for the Arena Pack /
        // Everything Bundle purchase (hasAllEnvironments), Premium, AND the
        // battle-count threshold. The old bespoke check here only looked at
        // isSubscribed, so owning the Arena Pack left arenas locked.
        !settings.isEnvironmentUnlocked(env)
    }

    private func isNew(_ env: BattleEnvironment) -> Bool {
        switch env {
        case .arctic, .desert: return true
        default: return false
        }
    }
}

// MARK: - Arena Tile

private struct ArenaTile: View {
    let env: BattleEnvironment
    let selected: Bool
    let locked: Bool
    let isNew: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(locked ? Kids.creamDeep : Color.white)
                .overlay(
                    RetroPanelShape(cornerRadius: 18, style: .continuous)
                        .stroke(selected ? Kids.sun : Kids.ink, lineWidth: selected ? 4 : 3)
                )
                .aspectRatio(1, contentMode: .fit)
                .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: selected ? 4 : 3)

            VStack(spacing: 4) {
                RetroArenaThumbnail(environment: env)
                    .frame(height: 38)
                    .opacity(locked ? 0.35 : 1)
                    .overlay {
                        if locked { Image(systemName: "lock.fill").foregroundColor(Kids.ink) }
                    }
                Text(env.name)
                    .font(Kids.fredoka(12, weight: .bold))
                    .foregroundColor(locked ? Kids.inkSoft : Kids.ink)
                Text(shortTag(env))
                    .font(Kids.nunito(9, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)

            if isNew && !locked {
                Text("NEW")
                    .font(Kids.fredoka(9, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RetroPanelShape().fill(Kids.grass).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                    .offset(x: -6, y: -6)
            }
        }
        .scaleEffect(selected ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
    }

    private func shortTag(_ e: BattleEnvironment) -> String {
        switch e {
        case .grassland: return "No advantage"
        case .ocean:     return "Sea animals win"
        case .sky:       return "Flyers soar"
        case .arctic:    return "Cold-weather pros"
        case .desert:    return "Speed & stamina"
        case .jungle:    return "Agility wins"
        case .volcano:   return "Raw power"
        case .night:     return "Mythic hunters"
        case .storm:     return "Fast & fierce"
        }
    }
}
