import SwiftUI

struct PreBattleSheet: View {
    let fighter1: Animal
    let fighter2: Animal
    @Binding var isPresented: Bool
    @Binding var selectedEnvironment: BattleEnvironment
    @Binding var arenaEffectsEnabled: Bool
    var onFight: () -> Void

    @ObservedObject private var settings = UserSettings.shared
    @State private var showEnvironmentsPackSheet = false
    @State private var lockedEnvironmentForAd: BattleEnvironment? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Title
                Text("CHOOSE YOUR ARENA")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textTertiary)
                    .tracking(2)
                    .padding(.bottom, 20)

                // Fighter matchup row
                HStack(spacing: 0) {
                    fighterBadge(animal: fighter1, accent: Theme.orange)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Theme.orange, Theme.yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.orange.opacity(0.5), radius: 8)
                        Text("VS").pixelText(size: 10, color: .white)
                    }
                    Spacer()
                    fighterBadge(animal: fighter2, accent: Theme.cyan)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)

                // Arena grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(BattleEnvironment.allCases) { env in
                            arenaCell(env)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Arena effects toggle
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arena Effects")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text(arenaEffectsEnabled
                             ? "Arena shapes the outcome"
                             : "Pure animal vs animal")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    Toggle("", isOn: $arenaEffectsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Theme.orange))
                        .labelsHidden()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.cardFill)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Fight button
                Button(action: {
                    HapticsService.shared.medium()
                    isPresented = false
                    onFight()
                }) {
                    HStack(spacing: 12) {
                        Text("⚔️").font(.system(size: 22))
                        Text("LET'S FIGHT!")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("⚔️").font(.system(size: 22))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(
                                colors: [Theme.orange, Theme.yellow],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .overlay(RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1))
                    )
                    .shadow(color: Theme.orange.opacity(0.6), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .sheet(isPresented: $showEnvironmentsPackSheet) {
            EnvironmentsPackSheet(isPresented: $showEnvironmentsPackSheet)
        }
        .alert(
            "Unlock \(lockedEnvironmentForAd?.name ?? "Arena")",
            isPresented: Binding(
                get: { lockedEnvironmentForAd != nil },
                set: { if !$0 { lockedEnvironmentForAd = nil } }
            )
        ) {
            Button("Watch Ad — Try Once") {
                guard let env = lockedEnvironmentForAd else { return }
                AdManager.shared.showRewardedAdForCustomCreature { granted in
                    if granted { selectedEnvironment = env }
                    lockedEnvironmentForAd = nil
                }
            }
            Button("Unlock All Arenas — $2.99") {
                Task {
                    if let product = await StoreKitManager.shared.environmentsPackProduct {
                        _ = await StoreKitManager.shared.purchase(product)
                    }
                    lockedEnvironmentForAd = nil
                }
            }
            Button("Cancel", role: .cancel) { lockedEnvironmentForAd = nil }
        } message: {
            if let env = lockedEnvironmentForAd {
                Text("The \(env.name) arena is a premium environment. Watch a short ad for one free battle, or unlock all 9 arenas forever for $2.99.")
            }
        }
    }

    // MARK: - Fighter badge

    @ViewBuilder
    private func fighterBadge(animal: Animal, accent: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(accent.opacity(0.4), lineWidth: 1.5))
                Text(animal.emoji)
                    .font(.system(size: 34))
            }
            Text(animal.name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 100)
        }
    }

    // MARK: - Arena cell

    @ViewBuilder
    private func arenaCell(_ env: BattleEnvironment) -> some View {
        let isSelected = selectedEnvironment == env
        let isLocked = !settings.isEnvironmentUnlocked(env)

        Button(action: {
            HapticsService.shared.tap()
            if isLocked {
                if env.tier == .earned { showEnvironmentsPackSheet = true }
                else { lockedEnvironmentForAd = env }
            } else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    selectedEnvironment = env
                }
            }
        }) {
            VStack(spacing: 5) {
                Text(env.emoji)
                    .font(.system(size: 28))
                Text(env.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isLocked {
                    Text("🔒")
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(
                            colors: [env.accentColor.opacity(0.35), env.accentColor.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Theme.cardFill))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? env.accentColor.opacity(0.8) : Theme.cardBorder,
                                lineWidth: isSelected ? 2 : 1))
            )
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
