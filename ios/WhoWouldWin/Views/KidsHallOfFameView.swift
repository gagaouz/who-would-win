import SwiftUI

/// "Hall of Fame" — server-aggregated leaderboard of built-in animals
/// ranked by total wins, win rate, and popularity. Full-mode battles only.
struct KidsHallOfFameView: View {
    @ObservedObject private var service = LeaderboardService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var selectedTab: Tab = .wins
    @State private var appeared = false

    private enum Tab: String, CaseIterable, Identifiable {
        case wins, winRate, popularity
        var id: String { rawValue }
        var label: String {
            switch self {
            case .wins:       return "TOP WINS"
            case .winRate:    return "WIN STREAK"
            case .popularity: return "MOST PLAYED"
            }
        }
        var emoji: String {
            switch self {
            case .wins:       return "🏆"
            case .winRate:    return "🔥"
            case .popularity: return "⭐"
            }
        }
    }

    private var entries: [LeaderboardEntry] {
        switch selectedTab {
        case .wins:       return service.leaderboard.topByWins
        case .winRate:    return service.leaderboard.topByWinRate
        case .popularity: return service.leaderboard.topByPopularity
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Kids.peach.opacity(0.7), Kids.pink.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, isIPad ? 22 : 16)
                    .padding(.top, isIPad ? 14 : 10)
                    .padding(.bottom, isIPad ? 12 : 8)

                tabBar
                    .padding(.horizontal, isIPad ? 22 : 16)

                content
            }
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            Task { await service.refresh() }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

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
            StickerWord(text: "HALL OF FAME 🏆", fill: Kids.sun, fontSize: isIPad ? 26 : 20, tilt: -2)
                .rotationEffect(.degrees(-2))
            Spacer()
            Color.clear.frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: isIPad ? 10 : 6) {
            ForEach(Tab.allCases) { tab in
                Button {
                    HapticsService.shared.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.emoji).font(.system(size: isIPad ? 16 : 13))
                        Text(tab.label)
                            .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(Kids.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isIPad ? 10 : 8)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Kids.sun : Color.white)
                            .overlay(Capsule().stroke(Kids.ink, lineWidth: 2.5))
                    )
                    .shadow(color: Kids.ink.opacity(selectedTab == tab ? 0.10 : 0.04),
                            radius: 0, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, isIPad ? 10 : 6)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty && service.leaderboard.totalBattles == 0 {
            emptyState
        } else if entries.isEmpty {
            ScrollView {
                Text("Not enough battles in this category yet — play more!")
                    .font(Kids.nunito(isIPad ? 15 : 12, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.top, 60)
                    .padding(.horizontal, 28)
                Spacer()
            }
            .refreshable { await service.refresh(force: true) }
        } else {
            ScrollView {
                LazyVStack(spacing: isIPad ? 10 : 8) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                        row(rank: idx + 1, entry: entry)
                    }
                    footer
                        .padding(.top, isIPad ? 18 : 12)
                        .padding(.bottom, isIPad ? 32 : 24)
                }
                .padding(.horizontal, isIPad ? 22 : 16)
                .padding(.top, isIPad ? 10 : 6)
            }
            .refreshable { await service.refresh(force: true) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 40)
            Text("🏆").font(.system(size: isIPad ? 96 : 76))
            StickerWord(text: "NO BATTLES YET", fill: Kids.sun, fontSize: isIPad ? 22 : 18, tilt: -2)
            Text("Play some battles, then come back to see\nwho's leading the pack!")
                .font(Kids.nunito(isIPad ? 16 : 12, weight: .bold))
                .foregroundColor(Kids.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(rank: Int, entry: LeaderboardEntry) -> some View {
        let animal = Animals.all.first(where: { $0.id == entry.id })
        HStack(spacing: isIPad ? 14 : 10) {
            rankBadge(rank)
            if let a = animal {
                FighterPortrait(animal: a, size: isIPad ? 60 : 48, ringColor: ringColor(for: rank))
            } else {
                placeholder
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .lineLimit(1)
                Text(secondaryLabel(for: entry))
                    .font(Kids.nunito(isIPad ? 12 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            Spacer()
            primaryStatChip(for: entry)
        }
        .padding(.horizontal, isIPad ? 14 : 10)
        .padding(.vertical, isIPad ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
    }

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
        let (fill, txt) = rankStyle(rank)
        ZStack {
            Circle().fill(fill).overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                .frame(width: isIPad ? 34 : 28, height: isIPad ? 34 : 28)
            Text(txt)
                .font(Kids.fredoka(isIPad ? 14 : 12, weight: .bold))
                .foregroundColor(rank <= 3 ? Kids.ink : .white)
        }
    }

    private func rankStyle(_ rank: Int) -> (Color, String) {
        switch rank {
        case 1: return (Color(hex: "#FFD43B"), "🥇")
        case 2: return (Color(hex: "#C0C0C0"), "🥈")
        case 3: return (Color(hex: "#CD7F32"), "🥉")
        default: return (Kids.ink, "\(rank)")
        }
    }

    private func ringColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: "#FFD43B")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return Kids.peach
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color(hex: "#E1D5F0"))
            .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
            .frame(width: isIPad ? 60 : 48, height: isIPad ? 60 : 48)
            .overlay(Text("?").font(Kids.fredoka(20, weight: .bold)).foregroundColor(Kids.ink))
    }

    private func secondaryLabel(for entry: LeaderboardEntry) -> String {
        switch selectedTab {
        case .wins:
            return "\(entry.battles) battles · \(Int(entry.winRate * 100))% win rate"
        case .winRate:
            return "\(entry.wins) wins · \(entry.battles) battles"
        case .popularity:
            return "\(entry.wins) wins · \(Int(entry.winRate * 100))% win rate"
        }
    }

    @ViewBuilder
    private func primaryStatChip(for entry: LeaderboardEntry) -> some View {
        let (value, color) = primaryStat(for: entry)
        Text(value)
            .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
            .foregroundColor(Kids.ink)
            .padding(.horizontal, isIPad ? 12 : 9)
            .padding(.vertical, isIPad ? 6 : 4)
            .background(
                Capsule()
                    .fill(color)
                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
            )
    }

    private func primaryStat(for entry: LeaderboardEntry) -> (String, Color) {
        switch selectedTab {
        case .wins:       return ("\(entry.wins) W", Kids.grass)
        case .winRate:    return ("\(Int((entry.winRate * 100).rounded()))%", Kids.pink)
        case .popularity: return ("\(entry.battles)", Kids.sun)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            if service.isLoading {
                ProgressView().tint(Kids.inkSoft)
            }
            Text("Across \(service.leaderboard.totalBattles.formatted()) battles worldwide")
                .font(Kids.nunito(isIPad ? 12 : 10, weight: .bold))
                .foregroundColor(Kids.inkSoft)
            if let updated = service.lastFetchedAt {
                Text("Updated \(relativeTime(from: updated))")
                    .font(Kids.nunito(isIPad ? 11 : 9, weight: .bold))
                    .foregroundColor(Kids.inkSoft.opacity(0.7))
            }
            if let err = service.lastFetchError, !service.isLoading {
                VStack(spacing: 4) {
                    Button {
                        HapticsService.shared.tap()
                        Task { await service.refresh(force: true) }
                    } label: {
                        HStack(spacing: 4) {
                            Text("🔄").font(.system(size: isIPad ? 13 : 11))
                            Text("Tap to retry")
                                .font(Kids.fredoka(isIPad ? 12 : 10, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                        .padding(.horizontal, isIPad ? 12 : 10)
                        .padding(.vertical, isIPad ? 6 : 4)
                        .background(
                            Capsule().fill(.white).overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5))
                        )
                    }
                    .buttonStyle(.plain)
                    // Small grey subtext with the underlying error — useful for
                    // diagnosing flaky-network or cancellation issues without
                    // alarming the user.
                    Text(err)
                        .font(Kids.nunito(isIPad ? 10 : 8, weight: .regular))
                        .foregroundColor(Kids.inkSoft.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    private func relativeTime(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
