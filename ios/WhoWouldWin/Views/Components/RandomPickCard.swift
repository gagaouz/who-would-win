//
//  RandomPickCard.swift
//  WhoWouldWin
//
//  "🎲 RANDOM" tile shown as the first cell in every picker grid —
//  taps pick a random creature from the supplied pool. Styled to
//  match AnimalCard dimensions (orange/yellow gradient so it reads
//  as a special action rather than a fighter).
//

import SwiftUI

struct RandomPickCard: View {
    let onTap: () -> Void

    @State private var diceRotation: Double = 0

    var body: some View {
        Button(action: {
            HapticsService.shared.medium()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                diceRotation += 360
            }
            onTap()
        }) {
            ZStack {
                VStack(spacing: 5) {
                    Text("🎲")
                        .font(.system(size: 40))
                        .rotationEffect(.degrees(diceRotation))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)

                    Text("RANDOM")
                        .font(Theme.bungee(11))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(height: 28, alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(
                    ZStack {
                        // Bottom 3D edge — darker orange
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.orange.opacity(0.8))
                            .offset(y: 4)

                        // Main card face — orange→yellow gradient
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: [Theme.orange, Theme.yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))

                        // Top shine
                        VStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .frame(height: 30)
                                .padding(.horizontal, 3)
                                .padding(.top, 2)
                            Spacer()
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Theme.orange.opacity(0.45), radius: 6, x: 0, y: 3)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    HStack(spacing: 10) {
        RandomPickCard(onTap: {})
        RandomPickCard(onTap: {})
    }
    .padding()
    .background(Theme.homeBg)
}
