import SwiftUI

// MARK: - Parental Gate — Apple Kids Category compliance
// Presented before any real-money purchase or external link out of the app.
// Asks a random multiplication question with both factors in 6–9 (e.g.
// "What is 7 × 8?") — hard enough that a 6–9-year-old can't trivially pass,
// per standard parental-gate practice. A wrong answer regenerates a brand-new
// question so the gate can't be brute-forced, and the gate is shown on EVERY
// attempt (no cached "passed" state).

struct ParentGateSheet: View {
    @Binding var isPresented: Bool
    let onSuccess: () -> Void

    @State private var challenge = ParentGateChallenge.random()
    @State private var missed = false
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#EFE7FF"), Color(hex: "#D6ECFF")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close affordance — a kid is never trapped here.
                HStack {
                    Spacer()
                    Button {
                        HapticsService.shared.tap()
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle().fill(.white)
                                .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }
                .padding(.horizontal, 16).padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: isIPad ? 18 : 14) {
                            Text("🔒")
                                .font(.system(size: isIPad ? 72 : 56))
                                .scaleEffect(appeared ? 1 : 0.3)

                            StickerWord(text: "GROWN-UPS ONLY",
                                        fill: Kids.sun,
                                        fontSize: isIPad ? 34 : 26,
                                        tilt: -2)
                                .rotationEffect(.degrees(appeared ? 0 : -10))
                                .scaleEffect(appeared ? 1 : 0.3)

                            Text("Ask a parent to answer this question!")
                                .font(Kids.nunito(isIPad ? 16 : 13, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                                .multilineTextAlignment(.center)

                            // Question card
                            Text("What is \(challenge.a) × \(challenge.b)?")
                                .font(Kids.fredoka(isIPad ? 34 : 28, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isIPad ? 22 : 18)
                                .background(
                                    StickerShape(shape: RoundedRectangle(cornerRadius: 22, style: .continuous),
                                                 fill: .white, strokeWidth: 3.5)
                                )
                                .inkShadow(y: 4, opacity: 0.10)
                                .id("\(challenge.a)x\(challenge.b)")

                            if missed {
                                Text("Oops — not quite! Here's a new one.")
                                    .font(Kids.nunito(isIPad ? 14 : 12, weight: .heavy))
                                    .foregroundColor(Kids.pinkDeep)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Answer buttons
                            VStack(spacing: isIPad ? 12 : 10) {
                                ForEach(Array(challenge.answers.enumerated()), id: \.offset) { i, value in
                                    KidButton(title: "\(value)",
                                              color: [Kids.sky, Kids.pink, Kids.grass][i % 3],
                                              size: .md) {
                                        answer(value)
                                    }
                                }
                            }
                            .padding(.top, 2)

                            // Explicit cancel so a kid isn't trapped.
                            Button {
                                HapticsService.shared.tap()
                                isPresented = false
                            } label: {
                                Text("Cancel")
                                    .font(Kids.fredoka(isIPad ? 16 : 14, weight: .bold))
                                    .foregroundColor(Kids.inkSoft)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                            .padding(.bottom, 28)
                        }
                        .padding(.horizontal, 26)
                        .frame(maxWidth: isIPad ? 520 : .infinity)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, isIPad ? 14 : 6)
                }
            }
        }
        .onAppear {
            // Fresh question on every presentation — never reuse a passed one.
            challenge = .random()
            missed = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { appeared = true }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func answer(_ value: Int) {
        if value == challenge.correct {
            HapticsService.shared.success()
            isPresented = false
            // Let the sheet finish dismissing before running the gated action —
            // it may immediately present StoreKit UI or open a URL.
            let action = onSuccess
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { action() }
        } else {
            // Wrong answer: warn and swap in a brand-new question so the same
            // one can't be brute-forced by cycling the three buttons.
            HapticsService.shared.warning()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                missed = true
                challenge = .random(avoiding: challenge)
            }
        }
    }
}

// MARK: - Challenge model

struct ParentGateChallenge {
    let a: Int
    let b: Int
    let answers: [Int]   // correct + 2 plausible wrongs, shuffled
    var correct: Int { a * b }

    /// Two factors in 6–9, plus two plausible wrong products (off-by-one-factor
    /// style mistakes) shuffled in with the correct answer.
    static func random(avoiding previous: ParentGateChallenge? = nil) -> ParentGateChallenge {
        var a = Int.random(in: 6...9)
        var b = Int.random(in: 6...9)
        if let prev = previous {
            // Guarantee a genuinely new question after a wrong answer.
            while a == prev.a && b == prev.b {
                a = Int.random(in: 6...9)
                b = Int.random(in: 6...9)
            }
        }
        let correct = a * b

        var wrongs = Set<Int>()
        let candidates = [(a + 1) * b, a * (b + 1), (a - 1) * b, a * (b - 1),
                          correct + a, correct - b].shuffled()
        for c in candidates where wrongs.count < 2 && c != correct && c > 0 {
            wrongs.insert(c)
        }
        while wrongs.count < 2 {   // paranoia fallback — should never run
            let c = correct + Int.random(in: -12...12)
            if c != correct && c > 0 { wrongs.insert(c) }
        }

        return ParentGateChallenge(a: a, b: b, answers: ([correct] + wrongs).shuffled())
    }
}

// MARK: - Reusable presentation helper

extension View {
    /// Presents the parental gate as a sheet. `onSuccess` runs only after a
    /// grown-up answers the multiplication question correctly (and after the
    /// sheet has dismissed). Use a fresh gate for EVERY purchase / link tap —
    /// never cache a "passed" state.
    func parentGate(isPresented: Binding<Bool>, onSuccess: @escaping () -> Void) -> some View {
        sheet(isPresented: isPresented) {
            ParentGateSheet(isPresented: isPresented, onSuccess: onSuccess)
        }
    }
}
