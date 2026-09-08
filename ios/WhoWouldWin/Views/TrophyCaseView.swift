import SwiftUI

/// Browsable, in-app Trophy Case. Achievements used to live only in Game Center
/// (invisible to most kids); this surfaces them in the app's own look. Earned
/// trophies show their name; locked ones stay a mystery to chase.
struct TrophyCaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    @State private var appeared = false

    private let tracker = AchievementTracker.shared

    private var earned: Set<String> { tracker.earnedIDs }
    private var all: [String] { tracker.allIDs }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Kids.grape.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, isIPad ? 22 : 16)
                    .padding(.top, isIPad ? 14 : 10)

                progressCard
                    .padding(.horizontal, isIPad ? 22 : 16)
                    .padding(.vertical, isIPad ? 12 : 10)

                ScrollView {
                    let cols = Array(repeating: GridItem(.flexible(), spacing: isIPad ? 14 : 10),
                                     count: isIPad ? 4 : 3)
                    LazyVGrid(columns: cols, spacing: isIPad ? 14 : 10) {
                        ForEach(all, id: \.self) { id in
                            trophyTile(id: id, unlocked: earned.contains(id))
                        }
                    }
                    .padding(.horizontal, isIPad ? 22 : 16)
                    .padding(.bottom, 30)
                }
            }
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("✕")
                    .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
                    .background(Circle().fill(.white).overlay(Circle().stroke(Kids.ink, lineWidth: 2.5)))
            }
            .buttonStyle(.plain)
            Spacer()
            StickerWord(text: "TROPHY CASE 🏅", fill: Kids.sun, fontSize: isIPad ? 26 : 19, tilt: -2)
            Spacer()
            Color.clear.frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
        }
    }

    private var progressCard: some View {
        let count = tracker.earnedCount
        let total = tracker.totalCount
        return HStack(spacing: 12) {
            Text("🏆").font(.system(size: isIPad ? 38 : 30))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count) of \(total) trophies")
                    .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                    .foregroundColor(Kids.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "#F0EBF7"))
                        Capsule().fill(Kids.sun)
                            .frame(width: max(8, geo.size.width * CGFloat(total > 0 ? Double(count)/Double(total) : 0)))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    @ViewBuilder
    private func trophyTile(id: String, unlocked: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? Kids.sun : Color.white.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(unlocked ? Kids.ink : Kids.ink.opacity(0.35),
                                    style: StrokeStyle(lineWidth: unlocked ? 3 : 2,
                                                       dash: unlocked ? [] : [5, 3]))
                    )
                    .aspectRatio(1, contentMode: .fit)
                Text(unlocked ? "🏅" : "🔒")
                    .font(.system(size: isIPad ? 40 : 32))
                    .opacity(unlocked ? 1 : 0.5)
            }
            Text(unlocked ? AchievementFeed.displayName(fromRawId: id) : "???")
                .font(Kids.fredoka(isIPad ? 12 : 10, weight: .bold))
                .foregroundColor(unlocked ? Kids.ink : Kids.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(height: isIPad ? 30 : 26)
        }
    }
}
