import SwiftUI

/// First screen of a tournament run. User picks bracket size and selection mode.
/// On continue:
///  - random   → calls startNew() and lands in BracketPreview
///  - manual   → transitions to CreaturePickerView (full count)
///  - hybrid   → transitions to CreaturePickerView (partial count allowed)
struct TournamentSetupView: View {
    let onContinue: (BracketSize, SelectionMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var size: BracketSize = .eight
    @State private var mode: SelectionMode = .random
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Color(hex: "#FFC8C2"), Kids.grape.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Decorative twinkles — proportional positions so they don't bunch
            // in the top-left on iPad. GeometryReader gives us the actual size.
            GeometryReader { geo in
                let positions: [(CGFloat, CGFloat)] = [
                    (0.08, 0.10), (0.86, 0.14), (0.15, 0.24),
                    (0.80, 0.28), (0.22, 0.07), (0.55, 0.05),
                    (0.92, 0.42), (0.05, 0.42)
                ]
                ForEach(0..<positions.count, id: \.self) { i in
                    let (px, py) = positions[i]
                    Text("✨")
                        .font(.system(size: CGFloat(isIPad ? 18 : 12) + CGFloat(i % 3) * 3))
                        .opacity(0.7)
                        .position(x: geo.size.width * px, y: geo.size.height * py)
                }
            }
            .allowsHitTesting(false)

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 26 : 18) {
                        header
                        sizeSection
                        modeSection

                        KidButton(title: mode == .random ? "ROLL BRACKET!" : "PICK FIGHTERS",
                                  icon: mode == .random ? "🎲" : "✍️",
                                  color: Kids.grass, size: .lg) {
                            HapticsService.shared.tap()
                            onContinue(size, mode)
                        }
                        .padding(.horizontal, isIPad ? 8 : 4)
                        .padding(.top, isIPad ? 10 : 6)
                        .padding(.bottom, isIPad ? 32 : 20)
                    }
                    .padding(.horizontal, isIPad ? 28 : 18)
                    .padding(.top, isIPad ? 20 : 12)
                    .frame(maxWidth: isIPad ? 720 : .infinity)
                    .scaleEffect(appeared ? 1 : 0.95)
                    .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Text("✕")
                        .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
                        .background(Circle().fill(.white).overlay(Circle().stroke(Kids.ink, lineWidth: 2.5)))
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: isIPad ? 10 : 6) {
            Text("🏆")
                .font(.system(size: isIPad ? 84 : 56))
                .shadow(color: Kids.ink.opacity(0.09), radius: 0, x: 0, y: 4)

            StickerWord(text: "TOURNAMENT", fill: Kids.sun, fontSize: isIPad ? 42 : 28, tilt: -2)
                .rotationEffect(.degrees(-2))

            Text("Pick your bracket and start the hype!")
                .font(Kids.nunito(isIPad ? 17 : 13, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.top, isIPad ? 6 : 4)
        }
        .padding(.top, isIPad ? 12 : 8)
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            sectionLabel(icon: "🎯", text: "BRACKET SIZE")
            HStack(spacing: isIPad ? 12 : 8) {
                ForEach(BracketSize.allCases) { s in
                    SizeChoiceChip(size: s, isSelected: size == s, isIPad: isIPad) {
                        HapticsService.shared.tap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            size = s
                        }
                    }
                }
            }
        }
        .padding(isIPad ? 20 : 14)
        .background(card)
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 4)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            sectionLabel(icon: "🧑‍🎤", text: "FIGHTER SELECTION")
            VStack(spacing: isIPad ? 12 : 8) {
                ModeRow(title: "RANDOM ROLL",
                        subtitle: "Surprise me! Pick my whole bracket.",
                        emoji: "🎲",
                        color: Kids.sun,
                        isSelected: mode == .random,
                        isIPad: isIPad,
                        onTap: { mode = .random })
                ModeRow(title: "HAND-PICK ALL",
                        subtitle: "Choose every fighter yourself.",
                        emoji: "✍️",
                        color: Kids.pink,
                        isSelected: mode == .manual,
                        isIPad: isIPad,
                        onTap: { mode = .manual })
                ModeRow(title: "MIX IT UP",
                        subtitle: "Pick a few, fill the rest at random.",
                        emoji: "🎯",
                        color: Kids.grape,
                        isSelected: mode == .hybrid,
                        isIPad: isIPad,
                        onTap: { mode = .hybrid })
            }
        }
        .padding(isIPad ? 20 : 14)
        .background(card)
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 4)
    }

    private func sectionLabel(icon: String, text: String) -> some View {
        HStack(spacing: isIPad ? 8 : 6) {
            Text(icon).font(.system(size: isIPad ? 22 : 16))
            Text(text)
                .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                .tracking(1)
                .foregroundColor(Kids.ink)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
    }
}

// MARK: - Size chip (Kids-styled)

private struct SizeChoiceChip: View {
    let size: BracketSize
    let isSelected: Bool
    let isIPad: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: isIPad ? 4 : 2) {
                Text("\(size.rawValue)")
                    .font(Kids.fredoka(isIPad ? 40 : 28, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text("FIGHTERS")
                    .font(Kids.fredoka(isIPad ? 12 : 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Kids.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 18 : 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Kids.sun : Color.white)
                    .overlay(isSelected ? RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: isSelected ? 3 : 2))
            )
            .shadow(color: Kids.ink.opacity(isSelected ? 0.18 : 0.08), radius: 0, x: 0, y: isSelected ? 4 : 2)
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode row (Kids-styled)

private struct ModeRow: View {
    let title: String
    let subtitle: String
    let emoji: String
    let color: Color
    let isSelected: Bool
    let isIPad: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: isIPad ? 16 : 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: isIPad ? 16 : 12, style: .continuous)
                        .fill(color)
                        .overlay(RoundedRectangle(cornerRadius: isIPad ? 16 : 12, style: .continuous).fill(Kids.sheen))
                        .overlay(RoundedRectangle(cornerRadius: isIPad ? 16 : 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 60 : 44, height: isIPad ? 60 : 44)
                    Text(emoji).font(.system(size: isIPad ? 30 : 22))
                }
                VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                    Text(title)
                        .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(subtitle)
                        .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(isSelected ? Kids.grass : Color.white)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 34 : 26, height: isIPad ? 34 : 26)
                    if isSelected {
                        Text("✓").font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold)).foregroundColor(Kids.ink)
                    }
                }
            }
            .padding(isIPad ? 14 : 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? color.opacity(0.18) : Color(hex: "#F7F2FF"))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.ink.opacity(isSelected ? 0.45 : 0.2), lineWidth: isSelected ? 2 : 1.5))
            )
        }
        .buttonStyle(.plain)
    }
}
