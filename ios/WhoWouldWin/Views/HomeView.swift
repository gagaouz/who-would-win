import SwiftUI

struct HomeView: View {
    @State private var showHelp = false
    @State private var showDebug = false
    @State private var showDisclaimer = true

    private var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#0A0A1A"),
                Color(hex: "#12082A"),
                Color(hex: "#0A1628")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen gradient background
                appBackground
                    .ignoresSafeArea()

                // Star/dot pattern overlay
                StarFieldOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer()

                    // Title logo image
                    Image("TitleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 16)

                    Spacer()
                        .frame(height: 32)

                    // Play Now button
                    NavigationLink(destination: AnimalPickerView()) {
                        Text("PLAY NOW ⚔️")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color(hex: "#FF6B35").opacity(0.5), radius: 16, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 50)
                }

                // "?" info button — top right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showHelp = true }) {
                            Image(systemName: "questionmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
        }
        .sheet(isPresented: $showDebug) {
            DebugMenuSheet()
        }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerSheet()
        }
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#0A0A1A").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                Text("🐾")
                    .font(.system(size: 64))
                    .padding(.bottom, 20)

                // Title
                Text("Just For Fun!")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)

                // Body
                VStack(spacing: 12) {
                    disclaimerLine("🎮", "This is a fantasy game — no real animals are involved or harmed.")
                    disclaimerLine("❤️", "We love animals and do not support or condone animal fighting of any kind.")
                    disclaimerLine("🤖", "All battles are decided by AI based on fun facts — it's all made up!")
                    disclaimerLine("👨‍👩‍👧", "Best enjoyed with a parent or guardian for younger players.")
                }
                .padding(.horizontal, 28)

                Spacer()

                // OK button
                Button(action: { dismiss() }) {
                    Text("Got it — let's play! ⚔️")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .shadow(color: Color(hex: "#FF6B35").opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)   // must tap the button, can't swipe away
    }

    private func disclaimerLine(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Star Field Overlay

struct StarFieldOverlay: View {
    // Deterministic dot positions generated from a fixed seed pattern
    private let dots: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = {
        var result: [(CGFloat, CGFloat, CGFloat, Double)] = []
        // Use a simple deterministic spread so it looks natural
        let positions: [(CGFloat, CGFloat)] = [
            (0.05, 0.04), (0.18, 0.12), (0.32, 0.07), (0.47, 0.02), (0.61, 0.09),
            (0.75, 0.05), (0.88, 0.14), (0.93, 0.03), (0.12, 0.20), (0.28, 0.25),
            (0.42, 0.18), (0.55, 0.22), (0.68, 0.17), (0.82, 0.28), (0.97, 0.21),
            (0.08, 0.35), (0.22, 0.40), (0.38, 0.33), (0.51, 0.38), (0.64, 0.30),
            (0.79, 0.42), (0.91, 0.36), (0.15, 0.52), (0.30, 0.48), (0.44, 0.55),
            (0.58, 0.50), (0.72, 0.58), (0.85, 0.53), (0.96, 0.47), (0.03, 0.60),
            (0.20, 0.65), (0.35, 0.62), (0.49, 0.68), (0.63, 0.63), (0.77, 0.70),
            (0.90, 0.66), (0.07, 0.75), (0.24, 0.72), (0.40, 0.78), (0.54, 0.74),
            (0.67, 0.80), (0.81, 0.76), (0.94, 0.83), (0.11, 0.88), (0.27, 0.85),
            (0.43, 0.91), (0.57, 0.87), (0.71, 0.93), (0.86, 0.89), (0.99, 0.95)
        ]
        let sizes: [CGFloat] = [1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5,
                                1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0,
                                2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0,
                                1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5,
                                1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0]
        let opacities: [Double] = [0.6, 0.3, 0.8, 0.5, 0.4, 0.7, 0.3, 0.6, 0.5, 0.8,
                                   0.4, 0.3, 0.6, 0.5, 0.7, 0.3, 0.8, 0.4, 0.6, 0.5,
                                   0.7, 0.3, 0.8, 0.4, 0.6, 0.5, 0.7, 0.3, 0.8, 0.4,
                                   0.6, 0.5, 0.7, 0.3, 0.8, 0.4, 0.6, 0.5, 0.7, 0.3,
                                   0.8, 0.4, 0.6, 0.5, 0.7, 0.3, 0.8, 0.4, 0.6, 0.5]
        for (i, pos) in positions.enumerated() {
            result.append((pos.0, pos.1, sizes[i % sizes.count], opacities[i % opacities.count]))
        }
        return result
    }()

    var body: some View {
        Canvas { context, size in
            for dot in dots {
                let x = dot.x * size.width
                let y = dot.y * size.height
                let r = dot.size / 2
                let rect = CGRect(x: x - r, y: y - r, width: dot.size, height: dot.size)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(dot.opacity))
                )
            }
        }
    }
}

// MARK: - Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var sheetBackground: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#0A0A1A"), Color(hex: "#12082A"), Color(hex: "#0A1628")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            sheetBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("HOW TO PLAY")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Rectangle()
                        .fill(Color(hex: "#FF6B35").opacity(0.6))
                        .frame(width: 40, height: 2)
                        .cornerRadius(1)
                }
                .padding(.top, 32)
                .padding(.bottom, 28)

                // Steps
                VStack(spacing: 20) {
                    HelpRow(number: "1", text: "Pick any two animals from the list.")
                    HelpRow(number: "2", text: "Tap FIGHT! to start the battle.")
                    HelpRow(number: "3", text: "Watch the epic battle play out!")
                    HelpRow(number: "4", text: "Learn a fun fact about the winner.")
                }
                .padding(.horizontal, 24)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Got it!")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color(hex: "#FF6B35").opacity(0.45), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
    }
}

struct HelpRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(number)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#FFD700"))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: "#FFD700").opacity(0.15))
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
                        )
                )

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Debug Menu Sheet

struct DebugMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backendURL: String = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A1A"), Color(hex: "#12082A"), Color(hex: "#0A1628")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("DEBUG MENU")
                    .pixelText(size: 14, color: Color(hex: "#FF6B35"))
                    .padding(.top, 32)
                    .padding(.bottom, 24)

                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(spacing: 16) {
                    Button("Simulate API Success") {
                        print("[DEBUG] Simulating API success")
                    }
                    .buttonStyle(GradientButtonStyle(
                        gradient: LinearGradient(
                            colors: [Color(hex: "#4ADE80"), Color(hex: "#22c55e")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        shadowColor: Color(hex: "#4ADE80"),
                        height: 50
                    ))

                    Button("Simulate API Failure") {
                        print("[DEBUG] Simulating API failure")
                    }
                    .buttonStyle(GradientButtonStyle(
                        gradient: LinearGradient(
                            colors: [Color(hex: "#EF4444"), Color(hex: "#dc2626")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        shadowColor: Color(hex: "#EF4444"),
                        height: 50
                    ))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("OVERRIDE BACKEND URL")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)

                        TextField("https://...", text: $backendURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                            .onSubmit {
                                print("[DEBUG] Override backend URL: \(backendURL)")
                            }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HomeView()
}
