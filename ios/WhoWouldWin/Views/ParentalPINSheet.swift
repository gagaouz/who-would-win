import SwiftUI

/// Kids-styled PIN entry sheet with two modes: setup and verify.
/// - `setup`: parent picks a 4-digit PIN twice; on match, calls onSuccess.
/// - `verify`: parent enters the existing PIN; on match, calls onSuccess.
struct ParentalPINSheet: View {
    enum Mode: Identifiable {
        case setup, verify
        var id: Int { self == .setup ? 0 : 1 }
    }

    let mode: Mode
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var entry: String = ""
    @State private var confirmEntry: String = ""
    @State private var stage: Stage = .enter
    @State private var error: String? = nil
    @State private var shake: CGFloat = 0
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private enum Stage { case enter, confirm }

    private var titleText: String {
        switch (mode, stage) {
        case (.setup, .enter):   return "SET A PIN"
        case (.setup, .confirm): return "CONFIRM PIN"
        case (.verify, _):       return "PARENT PIN"
        }
    }

    private var subtitleText: String {
        switch (mode, stage) {
        case (.setup, .enter):   return "Pick a 4-digit PIN that's hard for your kid to guess."
        case (.setup, .confirm): return "Enter the same 4 digits again."
        case (.verify, _):       return "Enter your parent PIN to change this setting."
        }
    }

    var body: some View {
        ZStack {
            SkyBG()

            VStack(spacing: isIPad ? 24 : 18) {
                RetroSymbol("🔒", size: isIPad ? 96 : 64)
                    .padding(.top, isIPad ? 50 : 32)
                    .scaleEffect(appeared ? 1 : 0.6)

                StickerWord(text: titleText, fill: Kids.sun, fontSize: isIPad ? 32 : 24, tilt: -2)

                Text(subtitleText)
                    .font(Kids.nunito(isIPad ? 17 : 13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isIPad ? 40 : 28)

                pinDots
                    .offset(x: shake)

                if let err = error {
                    Text(err)
                        .font(Kids.fredoka(isIPad ? 14 : 12, weight: .bold))
                        .foregroundColor(Kids.pinkDeep)
                        .transition(.opacity)
                }

                keypad
                    .padding(.top, isIPad ? 12 : 6)

                Button(action: {
                    HapticsService.shared.tap()
                    onCancel()
                }) {
                    Text("Cancel")
                        .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .underline()
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: isIPad ? 600 : .infinity)
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appeared = true }
        }
        .presentationDetents(isIPad ? [.large] : [.large])
        .presentationDragIndicator(.visible)
    }

    private var pinDots: some View {
        let active = (stage == .confirm ? confirmEntry : entry).count
        return HStack(spacing: isIPad ? 18 : 14) {
            ForEach(0..<4, id: \.self) { i in
                RetroPanelShape()
                    .fill(i < active ? Kids.ink : Color.white)
                    .frame(width: isIPad ? 22 : 18, height: isIPad ? 22 : 18)
                    .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                    .scaleEffect(i < active ? 1.0 : 0.85)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: active)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: isIPad ? 14 : 10) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: isIPad ? 14 : 10) {
                    ForEach(1..<4, id: \.self) { col in
                        digitButton("\(row * 3 + col)")
                    }
                }
            }
            HStack(spacing: isIPad ? 14 : 10) {
                Color.clear.frame(width: keySize, height: keySize)
                digitButton("0")
                backspaceButton
            }
        }
    }

    private var keySize: CGFloat { isIPad ? 84 : 64 }

    private func digitButton(_ digit: String) -> some View {
        Button {
            HapticsService.shared.tap()
            append(digit)
        } label: {
            Text(digit)
                .font(Kids.fredoka(isIPad ? 36 : 26, weight: .bold))
                .foregroundColor(Kids.ink)
                .frame(width: keySize, height: keySize)
                .background(
                    RetroPanelShape().fill(.white)
                        .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                )
                .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var backspaceButton: some View {
        Button {
            HapticsService.shared.tap()
            removeLast()
        } label: {
            RetroSymbol("⌫", size: isIPad ? 30 : 22)
                .foregroundColor(Kids.ink)
                .frame(width: keySize, height: keySize)
                .background(
                    RetroPanelShape().fill(Kids.peach)
                        .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                )
                .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry logic

    private func append(_ digit: String) {
        switch stage {
        case .enter:
            guard entry.count < 4 else { return }
            entry.append(digit)
            if entry.count == 4 { handleFullEntry() }
        case .confirm:
            guard confirmEntry.count < 4 else { return }
            confirmEntry.append(digit)
            if confirmEntry.count == 4 { handleFullConfirm() }
        }
    }

    private func removeLast() {
        switch stage {
        case .enter:   _ = entry.popLast()
        case .confirm: _ = confirmEntry.popLast()
        }
        error = nil
    }

    private func handleFullEntry() {
        switch mode {
        case .setup:
            stage = .confirm
            error = nil
        case .verify:
            if ParentalPIN.verify(entry) {
                HapticsService.shared.success()
                onSuccess()
            } else {
                wrongPIN()
                entry = ""
            }
        }
    }

    private func handleFullConfirm() {
        if confirmEntry == entry {
            ParentalPIN.setPIN(entry)
            HapticsService.shared.success()
            onSuccess()
        } else {
            wrongPIN(message: "PINs don't match. Try again.")
            stage = .enter
            entry = ""
            confirmEntry = ""
        }
    }

    private func wrongPIN(message: String = "Wrong PIN. Try again.") {
        HapticsService.shared.warning()
        withAnimation(.default) { error = message }
        // Brief horizontal shake of the dots
        shake = -10
        withAnimation(.easeInOut(duration: 0.08)) { shake = 10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.08)) { shake = -8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.08)) { shake = 6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeInOut(duration: 0.08)) { shake = 0 }
        }
    }
}
