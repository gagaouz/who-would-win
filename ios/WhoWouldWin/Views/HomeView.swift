import SwiftUI

struct HomeView: View {
    @AppStorage("hasSeenDisclaimer") private var hasSeenDisclaimer = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showDisclaimer = false
    @State private var disclaimerShownThisSession = false
    @State private var playPulse = false
    @State private var titleGlow = false
    // Single bounce value — both animals use it so they always stay level
    @State private var animalBounce: CGFloat = 0
    @State private var vsScale: CGFloat = 1.0

    private let heroPairs: [(String, String)] = [
        ("🦁", "🐯"), ("🦈", "🐊"), ("🦅", "🐺"),
        ("🐘", "🦏"), ("🦍", "🐻"), ("🦁", "🦈")
    ]
    @State private var pairIndex = 0
    @State private var pairTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.mainBg.ignoresSafeArea()
                SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

                // Settings gear — top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticsService.shared.tap()
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Theme.cardFill))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }

                VStack(spacing: 0) {
                    Spacer()

                    // Two hero animals — same bounce state so they're always level
                    HStack(alignment: .center, spacing: 0) {
                        Text(heroPairs[pairIndex].0)
                            .font(.system(size: 80))
                            .shadow(color: Theme.orange.opacity(0.4), radius: 12, x: 0, y: 0)
                            .transition(.scale.combined(with: .opacity))

                        Spacer()

                        Text("⚡")
                            .font(.system(size: 36))
                            .scaleEffect(vsScale)
                            .shadow(color: Theme.yellow.opacity(0.8), radius: 10, x: 0, y: 0)

                        Spacer()

                        Text(heroPairs[pairIndex].1)
                            .font(.system(size: 80))
                            .shadow(color: Theme.cyan.opacity(0.4), radius: 12, x: 0, y: 0)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.horizontal, 40)
                    .offset(y: animalBounce)
                    .padding(.bottom, 28)

                    // Wild pixel-font title
                    VStack(spacing: 10) {
                        // "ANIMAL VS ANIMAL" in two lines for better fit
                        VStack(spacing: 2) {
                            Text("ANIMAL")
                                .font(.custom("PressStart2P-Regular", size: 28))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.orange, Theme.yellow],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .shadow(color: Theme.orange.opacity(titleGlow ? 0.9 : 0.4), radius: titleGlow ? 18 : 8, x: 0, y: 0)

                            Text("VS ANIMAL")
                                .font(.custom("PressStart2P-Regular", size: 22))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.yellow, Theme.orange],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .shadow(color: Theme.orange.opacity(titleGlow ? 0.8 : 0.3), radius: titleGlow ? 14 : 6, x: 0, y: 0)
                        }
                        .multilineTextAlignment(.center)

                        Text("Who Would Win?")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 48)

                    // Big PLAY button
                    NavigationLink(destination: AnimalPickerView()) {
                        HStack(spacing: 10) {
                            Text("⚔️").font(.system(size: 28))
                            Text("LET'S BATTLE!")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("⚔️").font(.system(size: 28))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Theme.ctaGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        )
                        .shadow(
                            color: Theme.orange.opacity(playPulse ? 0.75 : 0.4),
                            radius: playPulse ? 32 : 16,
                            x: 0, y: 10
                        )
                        .scaleEffect(playPulse ? 1.025 : 1.0)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 28)

                    Spacer().frame(height: 28)

                    Button(action: { showHelp = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle").font(.system(size: 15))
                            Text("How to Play").font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Just for fun — no real animals are harmed 🐾")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if !hasSeenDisclaimer && !disclaimerShownThisSession {
            showDisclaimer = true
            disclaimerShownThisSession = true
        }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { playPulse = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { titleGlow = true }
            // Both animals share one bounce — always aligned
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { animalBounce = -14 }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { vsScale = 1.2 }
            pairTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    pairIndex = (pairIndex + 1) % heroPairs.count
                }
            }
        }
        .onDisappear {
            pairTimer?.invalidate()
            pairTimer = nil
        }
        .sheet(isPresented: $showHelp) { HelpSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerSheet(hasSeenDisclaimer: $hasSeenDisclaimer)
        }
    }
}

// MARK: - Spread Star Field (no clusters — evenly distributed)

struct SpreadStarField: View {
    // Hand-picked so no three dots are near each other in any quadrant
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.08, 0.18), (0.25, 0.08), (0.45, 0.15), (0.62, 0.05), (0.80, 0.20),
        (0.93, 0.11), (0.15, 0.32), (0.38, 0.28), (0.57, 0.35), (0.74, 0.30),
        (0.90, 0.40), (0.05, 0.50), (0.22, 0.44), (0.48, 0.52), (0.68, 0.47),
        (0.85, 0.55), (0.12, 0.65), (0.33, 0.60), (0.55, 0.68), (0.72, 0.63),
        (0.92, 0.70), (0.18, 0.80), (0.40, 0.75), (0.60, 0.82), (0.78, 0.77),
        (0.95, 0.85), (0.30, 0.90), (0.52, 0.95), (0.70, 0.88), (0.88, 0.93)
    ].enumerated().map { i, pos in
        let sizes: [CGFloat] =    [1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5,
                                   2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0,
                                   1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0]
        let opacities: [Double] = [0.5, 0.3, 0.7, 0.4, 0.6, 0.3, 0.5, 0.7, 0.4, 0.6,
                                   0.3, 0.7, 0.5, 0.3, 0.6, 0.4, 0.7, 0.3, 0.5, 0.6,
                                   0.4, 0.7, 0.3, 0.5, 0.6, 0.4, 0.7, 0.3, 0.5, 0.6]
        return (pos.0, pos.1, sizes[i % sizes.count], opacities[i % opacities.count])
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let starColor: Color = colorScheme == .light
                ? Color(hex: "#5533AA").opacity(0.15)
                : .white
            for star in stars {
                let x = star.x * size.width
                let y = star.y * size.height
                let r = star.size / 2
                let rect = CGRect(x: x - r, y: y - r, width: star.size, height: star.size)
                context.fill(Path(ellipseIn: rect), with: .color(starColor.opacity(star.opacity)))
            }
        }
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSeenDisclaimer: Bool
    @State private var dontShowAgain = false

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("🐾")
                    .font(.system(size: 70))
                    .padding(.bottom, 20)

                Text("Just For Fun!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.bottom, 20)

                VStack(spacing: 14) {
                    disclaimerLine("🎮", "This is a fantasy game — no real animals are involved or harmed.")
                    disclaimerLine("❤️", "We love animals and do not support animal fighting of any kind.")
                    disclaimerLine("🤖", "All battles are decided by AI based on fun facts — it's made up!")
                    disclaimerLine("👨‍👩‍👧", "Best enjoyed with a parent or guardian for younger players.")
                }
                .padding(.horizontal, 28)

                Spacer()

                // Don't show again toggle
                Button(action: { dontShowAgain.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(dontShowAgain ? Theme.orange : Theme.textSecondary)
                        Text("Don't show again")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.bottom, 16)

                Button(action: {
                    if dontShowAgain { hasSeenDisclaimer = true }
                    dismiss()
                }) {
                    Text("Got it — let's play! ⚔️")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(Theme.ctaGradient))
                        .shadow(color: Theme.orange.opacity(0.45), radius: 14, x: 0, y: 5)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    private func disclaimerLine(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 30)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("HOW TO PLAY")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.orange.opacity(0.7))
                        .frame(width: 48, height: 3)
                }
                .padding(.top, 36)
                .padding(.bottom, 32)

                VStack(spacing: 22) {
                    HelpRow(number: "1", emoji: "🐾", text: "Pick any two animals from the list.")
                    HelpRow(number: "2", emoji: "⚔️",  text: "Tap FIGHT! to start the battle.")
                    HelpRow(number: "3", emoji: "🎬", text: "Watch the epic battle play out!")
                    HelpRow(number: "4", emoji: "🎓", text: "Learn a fun fact about the winner.")
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Got it!")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Capsule().fill(Theme.ctaGradient))
                        .shadow(color: Theme.orange.opacity(0.45), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.medium])
    }
}

struct HelpRow: View {
    let number: String
    let emoji: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.18))
                    .overlay(Circle().stroke(Theme.orange.opacity(0.35), lineWidth: 1.5))
                    .frame(width: 40, height: 40)
                Text(emoji)
                    .font(.system(size: 14))
            }

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Debug Menu Sheet (kept for dev use)

struct DebugMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backendURL: String = ""

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("DEBUG MENU")
                    .pixelText(size: 14, color: Theme.orange)
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                Divider().background(Color.white.opacity(0.1))

                VStack(spacing: 16) {
                    Button("Simulate API Success") { print("[DEBUG] Simulating API success") }
                        .buttonStyle(GradientButtonStyle(
                            gradient: LinearGradient(colors: [Color(hex: "#4ADE80"), Color(hex: "#22c55e")], startPoint: .leading, endPoint: .trailing),
                            shadowColor: Color(hex: "#4ADE80"), height: 50
                        ))

                    Button("Simulate API Failure") { print("[DEBUG] Simulating API failure") }
                        .buttonStyle(GradientButtonStyle(
                            gradient: LinearGradient(colors: [Theme.red, Color(hex: "#dc2626")], startPoint: .leading, endPoint: .trailing),
                            shadowColor: Theme.red, height: 50
                        ))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("OVERRIDE BACKEND URL")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
                            .tracking(1)

                        TextField("https://...", text: $backendURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.cardFill)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                            )
                            .onSubmit { print("[DEBUG] Override backend URL: \(backendURL)") }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20).padding(.horizontal, 24)

                Spacer()

                Button("Close") { dismiss() }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HomeView()
}
