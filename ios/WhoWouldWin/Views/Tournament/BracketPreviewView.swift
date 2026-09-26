import SwiftUI

/// Shows the full first-round bracket. Player can CONFIRM to advance to grand-champion
/// wagering, or RE-ROLL (if unused) to shuffle seeding for 50 coins.
struct BracketPreviewView: View {
    let tournament: Tournament
    let onConfirm: () -> Void
    let onReroll: () -> Void
    let onForfeit: () -> Void

    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var showForfeitConfirm = false
    @State private var showRerollNotAffordable = false
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var rerollCost: Int { CoinStore.shared.tournamentBracketRerollCost }

    var body: some View {
        ZStack {
            SkyBG()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, isIPad ? 22 : 16)
                        .padding(.top, isIPad ? 14 : 10)
                        .padding(.bottom, isIPad ? 12 : 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: isIPad ? 12 : 8) {
                            HStack(spacing: isIPad ? 9 : 6) {
                                RetroSymbol("⚔️", size: isIPad ? 20 : 14)
                                Text("ROUND 1 MATCH-UPS")
                                    .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundColor(Kids.ink)
                                Spacer()
                            }
                            .padding(.bottom, isIPad ? 4 : 2)
                            .padding(.horizontal, isIPad ? 6 : 4)

                            ForEach(tournament.bracket.rounds.first ?? []) { matchup in
                                matchupRow(matchup)
                            }
                        }
                        .padding(.horizontal, isIPad ? 20 : 14)
                        .padding(.vertical, isIPad ? 14 : 10)
                    }

                    actionButtons
                        .padding(.horizontal, isIPad ? 26 : 18)
                        .padding(.top, isIPad ? 10 : 6)
                        .padding(.bottom, isIPad ? 24 : 16)
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                .scaleEffect(appeared ? 1 : 0.96)
                .opacity(appeared ? 1 : 0)
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Forfeit tournament?",
               isPresented: $showForfeitConfirm) {
            Button("Forfeit", role: .destructive) { onForfeit() }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text(settings.wageringEnabled
                 ? "Your bracket will be cleared. Already-spent coins are not refunded."
                 : "Your bracket will be cleared.")
        }
        .alert("Not enough coins",
               isPresented: $showRerollNotAffordable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need \(rerollCost) coins to re-roll.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { showForfeitConfirm = true } label: {
                Text("✕")
                    .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .frame(width: isIPad ? 50 : 44, height: isIPad ? 50 : 44)
                    .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
            }
            Spacer()
            VStack(spacing: isIPad ? 4 : 2) {
                Text("\(tournament.size.rawValue)-FIGHTER BRACKET")
                    .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text("Preview & confirm")
                    .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            Spacer()
            if settings.wageringEnabled {
                CoinChip(count: coinStore.balance)
            } else {
                Color.clear.frame(width: isIPad ? 50 : 44, height: isIPad ? 50 : 44)
            }
        }
    }

    // MARK: - Matchup row

    private func matchupRow(_ matchup: Matchup) -> some View {
        HStack(spacing: isIPad ? 12 : 8) {
            FighterMini(animal: matchup.fighter1, isIPad: isIPad)
            Text(matchup.fighter1.name)
                .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("VS")
                .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, isIPad ? 9 : 6).padding(.vertical, isIPad ? 3 : 2)
                .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
                .fixedSize()
            Text(matchup.fighter2.name)
                .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .trailing)
            FighterMini(animal: matchup.fighter2, isIPad: isIPad)
        }
        .padding(.vertical, isIPad ? 12 : 8)
        .padding(.horizontal, isIPad ? 14 : 10)
        .background(
            RetroPanelShape(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            KidButton(title: "CONTINUE", icon: "🎉",
                      color: Kids.grass, size: .lg) {
                HapticsService.shared.tap()
                onConfirm()
            }

            if !tournament.rerollUsed && settings.wageringEnabled {
                Button {
                    if coinStore.balance >= rerollCost {
                        HapticsService.shared.tap()
                        onReroll()
                    } else {
                        showRerollNotAffordable = true
                    }
                } label: {
                    HStack(spacing: isIPad ? 9 : 6) {
                        RetroSymbol("🎲", size: isIPad ? 22 : 16)
                        Text("RE-ROLL BRACKET")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                        HStack(spacing: isIPad ? 5 : 3) {
                            KidsGoldCoin(size: isIPad ? 20 : 14)
                            Text("\(rerollCost)")
                                .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isIPad ? 62 : 46)
                    .background(
                        RetroPanelShape(cornerRadius: 16, style: .continuous)
                            .fill(Kids.grape)
                            .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).fill(Kids.sheen))
                            .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
                    )
                    .compositingGroup().shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            } else if tournament.rerollUsed && settings.wageringEnabled {
                Text("Re-roll already used")
                    .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
        }
    }
}

// MARK: - Tiny fighter avatar for compact rows

private struct FighterMini: View {
    let animal: Animal
    let isIPad: Bool
    var body: some View {
        AnimalBubble(animal: animal, size: isIPad ? 38 : 28, tint: Kids.sun)
    }
}
