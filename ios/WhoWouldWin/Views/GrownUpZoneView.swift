import SwiftUI

/// Parent dashboard, reached through a parental gate from Settings. Gives the
/// grown-up an at-a-glance view of play activity plus the controls they care
/// about (daily reminder, safety summary, restore purchases) — all in one place
/// instead of scattered through the kid-facing settings list.
struct GrownUpZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared
    @ObservedObject private var collection = StickerCollection.shared
    @StateObject private var store = StoreKitManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var reminderBusy = false
    @State private var reminderDeniedNote = false
    @State private var restoreMessage: String? = nil
    @State private var showEraseConfirm = false
    // Tournament Wagering PIN control (moved here from Settings — it's a
    // parental control, so it lives in the parents' room).
    @State private var pinSheetMode: ParentalPINSheet.Mode? = nil
    // Parental gate for taps that leave the app (legal links). The zone itself
    // is behind the gate, but gates are never cached — each exit re-gates.
    @State private var showParentGate = false
    @State private var gatedAction: (() -> Void)? = nil

    private var collectedCount: Int {
        Animals.all.filter { collection.collected.contains($0.id) }.count
    }

    /// "What they're learning" — durable proof for the parent that the app
    /// teaches, built from data already tracked.
    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📚 WHAT THEY'RE LEARNING")
                .font(Kids.fredoka(12, weight: .bold)).foregroundColor(Kids.ink)
            learnRow("🔎", "Animals explored", "\(collectedCount) of \(Animals.all.filter { !$0.isCustom }.count)")
            if let acc = settings.predictionAccuracy {
                learnRow("🎯", "Battle predictions", "called \(settings.predictionsCorrect) of \(settings.predictionsTotal) right (\(acc)%)")
            } else {
                learnRow("🎯", "Battle predictions", "cheer for a fighter to start tracking!")
            }
            learnRow("🧠", "How it works", "every winner is decided by real size, speed & biology — not luck")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#EAF1FF"))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private func learnRow(_ emoji: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji).font(.system(size: 16)).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(Kids.fredoka(12, weight: .bold)).foregroundColor(Kids.ink)
                Text(value).font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#EAF2FF"), Color(hex: "#F3EAFF")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    statsGrid

                    learningCard

                    dailyReminderCard

                    wageringCard

                    safetyCard

                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Restore Purchases")
                            .font(Kids.fredoka(15, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                            )
                    }
                    .buttonStyle(.plain)

                    if let msg = restoreMessage {
                        Text(msg).font(Kids.nunito(12, weight: .bold)).foregroundColor(Kids.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    // Data deletion (COPPA / App Store expectation).
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        Text("Erase all data")
                            .font(Kids.fredoka(14, weight: .bold))
                            .foregroundColor(Kids.pink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Kids.pink.opacity(0.7), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    Text("Wipes all progress, stickers, trophies & coins from this device and iCloud. Purchases can be restored anytime.")
                        .font(Kids.nunito(10, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    legalLinks

                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                .frame(maxWidth: isIPad ? 640 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Erase all data?", isPresented: $showEraseConfirm) {
            Button("Erase everything", role: .destructive) {
                UserSettings.shared.eraseAllData()
                restoreMessage = "All data erased."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all progress, stickers, trophies and coins on this device and in iCloud. Purchases can be restored with “Restore Purchases.” This can't be undone.")
        }
        .sheet(item: $pinSheetMode) { mode in
            ParentalPINSheet(
                mode: mode,
                onSuccess: {
                    // Setup flow: just flipped from default ON → OFF.
                    // Verify flow: flip in whichever direction.
                    settings.wageringEnabled.toggle()
                    pinSheetMode = nil
                },
                onCancel: { pinSheetMode = nil }
            )
        }
        .parentGate(isPresented: $showParentGate) {
            gatedAction?()
            gatedAction = nil
        }
    }

    // MARK: - Tournament Wagering (parental control, PIN-protected)

    private var wageringCard: some View {
        Button {
            HapticsService.shared.tap()
            // First time turning OFF → PIN setup. Every change after → verify.
            pinSheetMode = ParentalPIN.isPINSet ? .verify : .setup
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Kids.grape)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: 40, height: 40)
                    Text("🪙").font(.system(size: 20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tournament Wagering")
                        .font(Kids.fredoka(15, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(wageringSubtitle)
                        .font(Kids.nunito(11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .lineLimit(2)
                }
                Spacer()
                wageringStatusPill
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
            )
            .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var wageringSubtitle: String {
        if !ParentalPIN.isPINSet {
            return "Tap to turn off coin wagering (sets a parent PIN)"
        }
        return settings.wageringEnabled
            ? "Coin wagering is on — tap to disable"
            : "Coin wagering is off — tap to re-enable"
    }

    private var wageringStatusPill: some View {
        let on = settings.wageringEnabled
        return Text(on ? "ON" : "OFF")
            .font(Kids.fredoka(12, weight: .bold))
            .tracking(1)
            .foregroundColor(Kids.ink)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(on ? Kids.grass : Color(hex: "#E8E0F0"))
                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
            )
    }

    // MARK: - Legal links (moved here from Settings — parents' business).
    // All of these leave the app, so each tap goes through the parental gate.

    private var legalLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                gatedLink("Privacy", url: "https://animal-vs-animal.com/privacy.html")
                Text("·").foregroundColor(Kids.inkSoft)
                gatedLink("Terms", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                Text("·").foregroundColor(Kids.inkSoft)
                gatedLink("Support", url: "https://animal-vs-animal.com/support.html")
            }
            .font(Kids.nunito(11, weight: .bold))
            .foregroundColor(Kids.grape)
        }
        .padding(.top, 2)
    }

    private func gatedLink(_ title: String, url: String) -> some View {
        Button(title) {
            HapticsService.shared.tap()
            gatedAction = {
                if let u = URL(string: url) {
                    UIApplication.shared.open(u)
                }
            }
            showParentGate = true
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            Text("👋 GROWN-UP ZONE")
                .font(Kids.fredoka(isIPad ? 24 : 19, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(Kids.fredoka(16, weight: .bold)).foregroundColor(Kids.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
    }

    private var statsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        return LazyVGrid(columns: cols, spacing: 12) {
            statTile("⚔️", "\(settings.totalBattleCount)", "Battles played")
            statTile("🔥", "\(settings.currentStreak)", "Day streak")
            statTile("⭐", "\(settings.longestStreak)", "Best streak")
            statTile("📖", "\(collectedCount)", "Stickers")
            statTile("🪙", coins.balance.formatted(), "Coins")
            statTile("🏅", "\(AchievementTracker.shared.earnedCount)", "Trophies")
        }
    }

    private func statTile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text(value).font(Kids.fredoka(20, weight: .bold)).foregroundColor(Kids.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private var dailyReminderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { settings.dailyReminderEnabled },
                set: { newValue in toggleReminder(newValue) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Play Reminder")
                        .font(Kids.fredoka(15, weight: .bold)).foregroundColor(Kids.ink)
                    Text("One gentle reminder a day (around 5pm)")
                        .font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                }
            }
            .tint(Kids.grass)
            .disabled(reminderBusy)

            if reminderDeniedNote {
                Text("Notifications are off for this app. Turn them on in iOS Settings → Notifications to use reminders.")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.pink)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🛡️ SAFE FOR KIDS")
                .font(Kids.fredoka(12, weight: .bold)).foregroundColor(Kids.ink)
            safetyRow("Purchases & external links are behind a grown-up gate.")
            safetyRow("We never sell data. Voice search stays on this device.")
            safetyRow("Ads are limited, non-personalized and child-directed.")
            safetyRow("Battle stories follow strict kid-friendly rules and are checked before they're shown.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#EAFBEA"))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private func safetyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("✓").font(Kids.fredoka(13, weight: .bold)).foregroundColor(Kids.grass)
            Text(text).font(Kids.nunito(12, weight: .bold)).foregroundColor(Kids.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func toggleReminder(_ on: Bool) {
        reminderBusy = true
        reminderDeniedNote = false
        Task {
            let effective = await NotificationService.shared.setDailyReminder(on)
            await MainActor.run {
                settings.dailyReminderEnabled = effective
                reminderDeniedNote = on && !effective
                reminderBusy = false
            }
        }
    }

    private func restore() async {
        await store.restorePurchases()
        await MainActor.run {
            restoreMessage = settings.hasRemovedAds || settings.isSubscribed
                ? "Purchases restored."
                : "Nothing to restore on this account."
        }
    }
}
