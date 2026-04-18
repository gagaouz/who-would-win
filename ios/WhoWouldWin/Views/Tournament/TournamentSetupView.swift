import SwiftUI

/// First screen of a tournament run. User picks bracket size and selection mode.
/// On continue:
///  - random   → calls startNew() and lands in BracketPreview
///  - manual   → transitions to CreaturePickerView (full count)
///  - hybrid   → transitions to CreaturePickerView (partial count allowed)
struct TournamentSetupView: View {
    let onContinue: (BracketSize, SelectionMode) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var size: BracketSize = .eight
    @State private var mode: SelectionMode = .random

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    sizeSection
                    modeSection

                    Spacer(minLength: 8)

                    Button {
                        onContinue(size, mode)
                    } label: {
                        Text(mode == .random ? "ROLL BRACKET" : "PICK FIGHTERS")
                    }
                    .buttonStyle(MegaButtonStyle(color: .orange, height: 70, cornerRadius: 22, fontSize: 22))
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("🏆 TOURNAMENT MODE 🏆")
                .font(Theme.bungee(22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.gold, Color(hex: "#FFF59D"), Theme.gold],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Theme.gold.opacity(0.6), radius: 8, x: 0, y: 0)
                .multilineTextAlignment(.center)

            Text("Pick your bracket and start the hype!")
                .font(Theme.bungee(13))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.top, 4)
    }

    private var sizeSection: some View {
        GamePanel(headerText: "BRACKET SIZE", headerColor: .blue) {
            HStack(spacing: 10) {
                ForEach(BracketSize.allCases) { s in
                    SizeChoiceChip(size: s, isSelected: size == s) {
                        size = s
                    }
                }
            }
        }
    }

    private var modeSection: some View {
        GamePanel(headerText: "FIGHTER SELECTION", headerColor: .purple) {
            VStack(spacing: 10) {
                ModeRow(
                    mode: .random,
                    title: "RANDOM ROLL",
                    subtitle: "Surprise me! Pick my whole bracket.",
                    emoji: "🎲",
                    isSelected: mode == .random,
                    onTap: { mode = .random }
                )
                ModeRow(
                    mode: .manual,
                    title: "HAND-PICK ALL",
                    subtitle: "Choose every fighter yourself.",
                    emoji: "✍️",
                    isSelected: mode == .manual,
                    onTap: { mode = .manual }
                )
                ModeRow(
                    mode: .hybrid,
                    title: "MIX IT UP",
                    subtitle: "Pick a few, fill the rest at random.",
                    emoji: "🎯",
                    isSelected: mode == .hybrid,
                    onTap: { mode = .hybrid }
                )
            }
        }
    }
}

// MARK: - Size chip

private struct SizeChoiceChip: View {
    let size: BracketSize
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(size.rawValue)")
                    .font(Theme.bungee(28))
                    .foregroundColor(.white)
                Text("FIGHTERS")
                    .font(Theme.bungee(10))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.orange.opacity(0.35) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.orange : Color.white.opacity(0.20),
                            lineWidth: isSelected ? 2.5 : 1.2)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Mode row

private struct ModeRow: View {
    let mode: SelectionMode
    let title: String
    let subtitle: String
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.bungee(13))
                        .foregroundColor(.white)
                        .tracking(0.5)
                    Text(subtitle)
                        .font(Theme.bungee(12))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isSelected ? Theme.gold : .white.opacity(0.4))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.gold.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.gold.opacity(0.9) : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
