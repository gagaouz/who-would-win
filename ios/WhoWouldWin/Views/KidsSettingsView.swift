import SwiftUI
import StoreKit

// MARK: - Settings — Animal Arena Jr.
//
// Reorganized 2026-07: the old screen stacked 17 sections (~10 purchase
// buttons) and mixed kid content with parent content. Now:
//   • KID LEVEL (this screen): profile, 3 toggles, Trophy Case, and three
//     doors — Shop & Unlocks, Grown-Up Zone, Game Center. No buy buttons.
//   • SHOP (KidsShopView, below in this file): ALL purchasing — coins,
//     Everything Bundle, packs, Remove Ads, Premium, Restore, Manage
//     Subscriptions. Every purchase still passes the parental gate.
//   • GROWN-UP ZONE: gained the Tournament Wagering PIN control and the
//     legal links (see GrownUpZoneView.swift).
// The dead "Light Mode" toggle was removed (the app forces light mode at the
// root; only the legacy dead SettingsView ever read the pref).
//
// KidsShopView lives in THIS file on purpose — no pbxproj registration needed.

struct KidsSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var collection = StickerCollection.shared
    @ObservedObject private var gc = GameCenterManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    @State private var appeared = false

    @State private var showGameCenterSignInAlert = false
    @State private var showNarrationLab = false
    @State private var showTrophyCase = false
    @State private var showGrownUpZone = false
    @State private var showShop = false

    // Parental gate (Kids Category): the Grown-Up Zone door and any tap that
    // leaves the app go through it. Never caches a "passed" state.
    @State private var showParentGate = false
    @State private var gatedAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            SkyBG()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 18 : 14) {
                        header
                        profileCard
                        quickTogglesCard
                        trophyCaseCard
                        shopCard
                        grownUpZoneCard
                        gameCenterCard
                        versionFooter
                        if UserSettings.showDevTools { narrationLabRow }
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, isIPad ? 20 : 14)
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
        .alert("Sign in to Game Center", isPresented: $showGameCenterSignInAlert) {
            Button("Open iOS Settings") {
                // Leaves the app — parental gate first.
                requireParentGate {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Sign in to Game Center in iOS Settings to unlock achievements and leaderboards.")
        }
        .parentGate(isPresented: $showParentGate) {
            gatedAction?()
            gatedAction = nil
        }
        .fullScreenCover(isPresented: $showTrophyCase) {
            NavigationStack { TrophyCaseView() }
        }
        .fullScreenCover(isPresented: $showGrownUpZone) {
            GrownUpZoneView()
        }
        .fullScreenCover(isPresented: $showShop) {
            KidsShopView()
        }
    }

    // MARK: - Parental gate plumbing

    /// Queues `action` to run only after the parental gate is passed.
    private func requireParentGate(_ action: @escaping () -> Void) {
        gatedAction = action
        showParentGate = true
    }

    // Dev/TestFlight-only entry point to the on-device narration A/B harness.
    // Gated at the call site by UserSettings.showDevTools (hidden in App Store builds).
    private var narrationLabRow: some View {
        Button { showNarrationLab = true } label: {
            HStack(spacing: 10) {
                RetroSymbol("🧪", size: 22)
                Text("Narration Lab (dev)")
                    .font(Kids.fredoka(isIPad ? 16 : 14, weight: .bold))
                    .foregroundColor(Kids.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Kids.inkSoft)
            }
            .padding(isIPad ? 16 : 14)
            .background(KidsSettingsCard())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showNarrationLab) { NarrationLabView() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            KidIconBtn(icon: "←", fill: .white) { dismiss() }
            Spacer()
            Text("Settings")
                .font(Kids.fredoka(isIPad ? 32 : 24, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            Color.clear.frame(width: isIPad ? 64 : 44, height: isIPad ? 64 : 44)
        }
        .padding(.top, isIPad ? 10 : 6)
    }

    // MARK: - Profile card
    // Absorbs the old About card's stats — one identity card instead of two.

    private var profileCard: some View {
        HStack(spacing: isIPad ? 16 : 12) {
            ZStack {
                RetroPanelShape(cornerRadius: 22, style: .continuous)
                    .fill(Kids.grape)
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                    .frame(width: isIPad ? 88 : 70, height: isIPad ? 88 : 70)
                RetroSymbol("🦊", size: isIPad ? 50 : 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Battler")
                    .font(Kids.fredoka(isIPad ? 22 : 18, weight: .bold))
                    .foregroundColor(Kids.ink)
                HStack(spacing: 6) {
                    StatChip(icon: "⭐", label: "Lv \(settings.totalBattleCount / 10 + 1)", color: Kids.sun)
                    StatChip(icon: "⚔️", label: "\(settings.totalBattleCount)", color: Kids.pink)
                    StatChip(icon: "📔", label: "\(collection.count)", color: Kids.sky)
                    StatChip(icon: "🔥", label: "\(settings.currentStreak)", color: Kids.peach)
                }
            }
            Spacer()
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
    }

    // MARK: - Toggles (Light Mode removed — it was wired to nothing)

    private var quickTogglesCard: some View {
        VStack(spacing: isIPad ? 10 : 8) {
            SettingRow(icon: "🔊", bg: Kids.sun,   label: "Sounds & Music",
                       value: settings.soundEnabled ? "On" : "Off",
                       toggle: Binding(get: { settings.soundEnabled },
                                       set: { settings.soundEnabled = $0 }))
            SettingRow(icon: "🗣️", bg: Kids.sky,  label: "Read Aloud",
                       value: settings.narrationEnabled ? "On" : "Off",
                       toggle: Binding(get: { settings.narrationEnabled },
                                       set: { settings.narrationEnabled = $0 }))
            SettingRow(icon: "📳", bg: Kids.pink, label: "Vibration",
                       value: settings.hapticsEnabled ? "On" : "Off",
                       toggle: Binding(get: { settings.hapticsEnabled },
                                       set: { settings.hapticsEnabled = $0 }))
        }
    }

    // MARK: - Doors (Trophy Case · Shop · Grown-Up Zone)

    private var trophyCaseCard: some View {
        Button {
            HapticsService.shared.tap()
            showTrophyCase = true
        } label: {
            KidsNavRow(emoji: "🏅", title: "Trophy Case",
                       subtitle: "\(AchievementTracker.shared.earnedCount) of \(AchievementTracker.shared.totalCount) trophies",
                       tint: Kids.sun, isIPad: isIPad)
        }
        .buttonStyle(.plain)
    }

    private var shopCard: some View {
        Button {
            HapticsService.shared.tap()
            showShop = true
        } label: {
            KidsNavRow(emoji: "🎁", title: "Shop & Unlocks",
                       subtitle: "Packs, coins & Premium — for grown-ups",
                       tint: Kids.grass, isIPad: isIPad)
        }
        .buttonStyle(.plain)
    }

    private var grownUpZoneCard: some View {
        Button {
            HapticsService.shared.tap()
            requireParentGate { showGrownUpZone = true }
        } label: {
            KidsNavRow(emoji: "👋", title: "Grown-Up Zone",
                       subtitle: "Controls, activity & safety — for parents",
                       tint: Kids.grape, isIPad: isIPad, lock: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Game Center

    private var gameCenterCard: some View {
        VStack(spacing: isIPad ? 12 : 10) {
            HStack(spacing: isIPad ? 12 : 10) {
                RetroSymbol("🏆", size: isIPad ? 26 : 22)
                Text("Game Center")
                    .font(Kids.fredoka(isIPad ? 19 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
                Spacer()
                if !gc.isAuthenticated {
                    Text("Sign in")
                        .font(Kids.fredoka(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, isIPad ? 10 : 8).padding(.vertical, isIPad ? 5 : 4)
                        .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                }
            }
            gcRow(emoji: "🏆", label: "Achievements", caption: "76 to unlock") {
                if gc.isAuthenticated {
                    GameCenterManager.shared.pendingAction = .achievements
                    dismiss()
                } else { showGameCenterSignInAlert = true }
            }
            gcRow(emoji: "📊", label: "Leaderboards", caption: "See how you rank!") {
                if gc.isAuthenticated {
                    GameCenterManager.shared.pendingAction = .leaderboards
                    dismiss()
                } else { showGameCenterSignInAlert = true }
            }
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    private func gcRow(emoji: String, label: String, caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: isIPad ? 14 : 12) {
                RetroSymbol(emoji, size: isIPad ? 24 : 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(Kids.fredoka(isIPad ? 16 : 14, weight: .bold)).foregroundColor(Kids.ink)
                    Text(caption).font(Kids.nunito(isIPad ? 13 : 11, weight: .bold)).foregroundColor(Kids.inkSoft)
                }
                Spacer()
                Text("›").font(Kids.fredoka(isIPad ? 24 : 20, weight: .bold)).foregroundColor(Kids.inkSoft)
            }
            .padding(isIPad ? 14 : 10)
            .background(
                RetroPanelShape(cornerRadius: 14, style: .continuous)
                    .fill(Kids.panel)
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink.opacity(0.2), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Version footer (replaces the old About card — its stats live in
    // the profile chips now)

    private var versionFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return Text("Animal vs Animal · v\(version) (\(build))")
            .font(Kids.nunito(isIPad ? 12 : 10, weight: .bold))
            .foregroundColor(Kids.inkSoft)
            .padding(.top, 2)
    }
}

// MARK: - Shop & Unlocks — ALL purchasing lives here now
//
// Everything that used to sprawl across the Settings scroll: coin bank,
// Everything Bundle, the four packs, Remove Ads, Premium, Restore, and the
// Manage Subscriptions link. Every real-money tap still passes the parental
// gate; Ask-to-Buy still surfaces the friendly "asked your grown-up" notice.

struct KidsShopView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared
    @StateObject private var store = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    @State private var appeared = false

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showStoreAlert = false
    @State private var showAskToBuyNotice = false

    // Parental gate — every purchase and external link funnels through this.
    @State private var showParentGate = false
    @State private var gatedAction: (() -> Void)? = nil

    var body: some View {
        ZStack {
            SkyBG()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 18 : 14) {
                        header
                        coinBankCard
                        everythingBundleCard
                        packCard(emoji: "🦖", title: "Prehistoric Pack",
                                 subtitle: "T-Rex, Megalodon, Mammoth +9 more",
                                 color: Kids.sun, unlocked: settings.isPrehistoricUnlocked,
                                 product: store.prehistoricPackProduct, fallbackPrice: "$1.99") {
                            Task {
                                if let p = store.prehistoricPackProduct { await purchaseAndNotify(p) }
                                else {
                                    #if DEBUG
                                    settings.prehistoricUnlocked = true
                                    #else
                                    await store.loadProducts(); showStoreAlert = true
                                    #endif
                                }
                            }
                        }
                        packCard(emoji: "🧚", title: "Fantasy Pack",
                                 subtitle: "Dragon, Unicorn, Phoenix +9 more",
                                 color: Kids.grape, unlocked: settings.isFantasyUnlocked,
                                 product: store.fantasyPackProduct, fallbackPrice: "$1.99") {
                            Task {
                                if let p = store.fantasyPackProduct { await purchaseAndNotify(p) }
                                else {
                                    #if DEBUG
                                    settings.fantasyUnlocked = true
                                    #else
                                    await store.loadProducts(); showStoreAlert = true
                                    #endif
                                }
                            }
                        }
                        packCard(emoji: "⚡", title: "Mythic Beasts",
                                 subtitle: "Thunderbird, Manticore, Roc +9 more",
                                 color: Kids.sunDeep, unlocked: settings.isMythicUnlocked,
                                 product: store.mythicPackProduct, fallbackPrice: "$2.99") {
                            Task {
                                if let p = store.mythicPackProduct { await purchaseAndNotify(p) }
                                else {
                                    #if DEBUG
                                    settings.mythicUnlocked = true
                                    #else
                                    await store.loadProducts(); showStoreAlert = true
                                    #endif
                                }
                            }
                        }
                        packCard(emoji: "🌍", title: "Arenas Pack",
                                 subtitle: "Jungle, Volcano, Night, Storm",
                                 color: Kids.grass, unlocked: settings.hasAllEnvironments,
                                 product: store.environmentsPackProduct, fallbackPrice: "$2.99") {
                            Task {
                                if let p = store.environmentsPackProduct { await purchaseAndNotify(p) }
                                else {
                                    #if DEBUG
                                    settings.environmentsUnlocked = true
                                    #else
                                    await store.loadProducts(); showStoreAlert = true
                                    #endif
                                }
                            }
                        }
                        removeAdsCard
                        premiumCard
                        restorePurchasesRow
                        legalFooter
                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, isIPad ? 20 : 14)
                    .frame(maxWidth: isIPad ? 680 : .infinity)
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(restoreMessage) }
        .alert("Store Unavailable", isPresented: $showStoreAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text("Couldn't load products. Please check your connection and try again.") }
        .alert("📨 Asked your grown-up!", isPresented: $showAskToBuyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchase will unlock when they say yes.")
        }
        .parentGate(isPresented: $showParentGate) {
            gatedAction?()
            gatedAction = nil
        }
    }

    // MARK: - Gate + purchase plumbing

    private func requireParentGate(_ action: @escaping () -> Void) {
        gatedAction = action
        showParentGate = true
    }

    /// Purchases and surfaces Ask to Buy: on `.pending` the kid sees a
    /// friendly "asked your grown-up" notice instead of a silent failure.
    /// The entitlement lands later via StoreKitManager's Transaction.updates
    /// listener if the parent approves.
    @MainActor
    private func purchaseAndNotify(_ product: Product) async {
        if await store.purchase(product) == .pending {
            showAskToBuyNotice = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            KidIconBtn(icon: "✕", fill: .white) { dismiss() }
            Spacer()
            Text("Shop & Unlocks")
                .font(Kids.fredoka(isIPad ? 30 : 22, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            Color.clear.frame(width: isIPad ? 64 : 44, height: isIPad ? 64 : 44)
        }
        .padding(.top, isIPad ? 10 : 6)
    }

    // MARK: - Coin bank

    private var coinBankCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 14 : 12) {
            HStack(spacing: isIPad ? 12 : 10) {
                KidsGoldCoin(size: isIPad ? 56 : 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Battle Coins")
                        .font(Kids.fredoka(isIPad ? 19 : 16, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text("Earn by playing · Spend to unlock")
                        .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                HStack(spacing: 4) {
                    KidsGoldCoin(size: isIPad ? 22 : 18)
                    Text(coins.balance.abbreviatedKidsCount)
                        .font(Kids.fredoka(isIPad ? 26 : 22, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                earnRow(amount: "+10", label: "every battle")
                earnRow(amount: "+25", label: "first battle each day")
                earnRow(amount: "+75", label: "watch an ad (8/day max)")
                if !settings.isSubscribed {
                    earnRow(amount: "2×", label: "with Premium 👑", emphasize: true)
                }
            }

            KidsPurchaseButton(
                label: store.coins1000Product.map { "Buy 1,000 Coins — \($0.displayPrice)" } ?? "Buy 1,000 Coins — $1.99",
                color: Kids.sun,
                isIPad: isIPad
            ) {
                requireParentGate {
                    Task {
                        if store.coins1000Product == nil { await store.loadProducts() }
                        if let p = store.coins1000Product { await purchaseAndNotify(p) }
                        else { showStoreAlert = true }
                    }
                }
            }
            Text("Coins are added instantly and never expire.")
                .font(Kids.nunito(isIPad ? 12 : 10, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    private func earnRow(amount: String, label: String, emphasize: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(amount)
                .font(Kids.fredoka(isIPad ? 15 : 13, weight: .bold))
                .foregroundColor(emphasize ? Kids.pink : Kids.ink)
            Text(label)
                .font(Kids.nunito(isIPad ? 14 : 12, weight: .bold))
                .foregroundColor(Kids.inkSoft)
            Spacer()
        }
    }

    // MARK: - Everything Bundle

    /// True once the bundle has nothing left to grant.
    private var ownsEverything: Bool {
        settings.adsRemoved
            && settings.isFantasyUnlocked && settings.isPrehistoricUnlocked
            && settings.isMythicUnlocked && settings.isOlympusUnlocked
            && settings.isMeleeUnlocked && settings.hasAllEnvironments
    }

    @ViewBuilder
    private var everythingBundleCard: some View {
        if !ownsEverything {
            VStack(alignment: .leading, spacing: isIPad ? 12 : 10) {
                HStack(spacing: isIPad ? 12 : 10) {
                    ZStack {
                        RetroPanelShape(cornerRadius: 14, style: .continuous)
                            .fill(Kids.sun)
                            .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                            .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                            .frame(width: isIPad ? 56 : 46, height: isIPad ? 56 : 46)
                        RetroSymbol("🎁", size: isIPad ? 28 : 24)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Everything Bundle")
                            .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                            .foregroundColor(Kids.ink)
                        Text("Every pack + Melee + Arenas + No Ads")
                            .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Text("BEST VALUE")
                        .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, isIPad ? 9 : 7).padding(.vertical, isIPad ? 5 : 4)
                        .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                }

                KidsPurchaseButton(
                    label: store.everythingBundleProduct.map { "Unlock Everything — \($0.displayPrice)" } ?? "Unlock Everything — $14.99",
                    color: Kids.sun,
                    isIPad: isIPad
                ) {
                    requireParentGate {
                        Task {
                            if let p = store.everythingBundleProduct { await purchaseAndNotify(p) }
                            else { await store.loadProducts(); showStoreAlert = true }
                        }
                    }
                }
            }
            .padding(isIPad ? 18 : 14)
            .background(
                RetroPanelShape(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.sun, lineWidth: 3.5))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
        }
    }

    // MARK: - Pack card

    @ViewBuilder
    private func packCard(emoji: String, title: String, subtitle: String, color: Color,
                          unlocked: Bool, product: Product?, fallbackPrice: String,
                          action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 10) {
            HStack(spacing: isIPad ? 12 : 10) {
                ZStack {
                    RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .fill(color)
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 56 : 46, height: isIPad ? 56 : 46)
                    RetroSymbol(emoji, size: isIPad ? 28 : 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(subtitle)
                        .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer()
                if unlocked {
                    Text("✓ OWNED")
                        .font(Kids.fredoka(isIPad ? 12 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, isIPad ? 10 : 8).padding(.vertical, isIPad ? 5 : 4)
                        .background(RetroPanelShape().fill(Kids.grass).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                }
            }

            if !unlocked {
                KidsPurchaseButton(
                    label: product.map { "Unlock — \($0.displayPrice)" } ?? "Unlock — \(fallbackPrice)",
                    color: color,
                    isIPad: isIPad
                ) {
                    requireParentGate(action)
                }
            }
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    // MARK: - Remove ads

    private var removeAdsCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 10) {
            HStack(spacing: isIPad ? 12 : 10) {
                ZStack {
                    RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .fill(Kids.peach)
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 56 : 46, height: isIPad ? 56 : 46)
                    RetroSymbol("🚫", size: isIPad ? 26 : 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.adsRemoved ? "Ads Removed" : "Remove Ads")
                        .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(settings.adsRemoved ? "Thanks for your support!" : "One-time purchase — no more ads ever")
                        .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                if settings.adsRemoved {
                    Text("✓").font(Kids.fredoka(isIPad ? 24 : 20, weight: .bold)).foregroundColor(Kids.grassDeep)
                }
            }
            if !settings.adsRemoved {
                KidsPurchaseButton(
                    label: store.removeAdsProduct.map { "Remove Ads — \($0.displayPrice)" } ?? "Remove Ads — $4.99",
                    color: Kids.peach,
                    isIPad: isIPad
                ) {
                    requireParentGate {
                        Task {
                            if let p = store.removeAdsProduct { await purchaseAndNotify(p) }
                            else {
                                #if DEBUG
                                settings.hasRemovedAds = true
                                #else
                                await store.loadProducts(); showStoreAlert = true
                                #endif
                            }
                        }
                    }
                }
            }
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    // MARK: - Premium

    private var premiumCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 10) {
            HStack(spacing: isIPad ? 12 : 10) {
                ZStack {
                    RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .fill(Kids.sun)
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 56 : 46, height: isIPad ? 56 : 46)
                    RetroSymbol("👑", size: isIPad ? 26 : 22)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.isSubscribed ? "Premium Active!" : "Get Premium")
                        .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(settings.isSubscribed ? "All features unlocked" : "Every pack + no ads + 2× coins")
                        .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                if settings.isSubscribed {
                    Text("✓").font(Kids.fredoka(isIPad ? 24 : 20, weight: .bold)).foregroundColor(Kids.grassDeep)
                }
            }
            if !settings.isSubscribed {
                VStack(alignment: .leading, spacing: 4) {
                    premiumFeature("No ads — ever")
                    premiumFeature("Every creature pack unlocked")
                    premiumFeature("Unlimited custom fighters")
                    premiumFeature("2× coins per battle")
                }
                .padding(.leading, 4)

                KidsPurchaseButton(
                    label: store.premiumMonthlyProduct.map { "Monthly — \($0.displayPrice)/mo" } ?? "Monthly — $2.99/mo",
                    color: Kids.grape,
                    isIPad: isIPad
                ) {
                    requireParentGate {
                        Task {
                            if let p = store.premiumMonthlyProduct { await purchaseAndNotify(p) }
                            else {
                                #if DEBUG
                                settings.isSubscribed = true; settings.hasRemovedAds = true
                                settings.fantasyUnlocked = true; settings.prehistoricUnlocked = true; settings.mythicUnlocked = true
                                #else
                                await store.loadProducts(); showStoreAlert = true
                                #endif
                            }
                        }
                    }
                }
                ZStack(alignment: .topTrailing) {
                    KidsPurchaseButton(
                        label: store.introOfferLabel(for: store.premiumAnnualProduct)
                            ?? store.premiumAnnualProduct.map { "Annual — \($0.displayPrice)/yr" } ?? "Annual — $19.99/yr",
                        color: Kids.sun,
                        isIPad: isIPad
                    ) {
                        requireParentGate {
                            Task {
                                if let p = store.premiumAnnualProduct { await purchaseAndNotify(p) }
                                else {
                                    #if DEBUG
                                    settings.isSubscribed = true; settings.hasRemovedAds = true
                                    settings.fantasyUnlocked = true; settings.prehistoricUnlocked = true; settings.mythicUnlocked = true
                                    #else
                                    await store.loadProducts(); showStoreAlert = true
                                    #endif
                                }
                            }
                        }
                    }
                    Text("BEST VALUE")
                        .font(Kids.fredoka(isIPad ? 10 : 8, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, isIPad ? 8 : 6).padding(.vertical, isIPad ? 3 : 2)
                        .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
                        .offset(x: -10, y: -7)
                        .rotationEffect(.degrees(8))
                }
            }
        }
        .padding(isIPad ? 18 : 14)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    private func premiumFeature(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("✓").font(Kids.fredoka(isIPad ? 14 : 12, weight: .bold)).foregroundColor(Kids.grassDeep)
            Text(text).font(Kids.nunito(isIPad ? 14 : 12, weight: .bold)).foregroundColor(Kids.ink)
        }
    }

    // MARK: - Restore

    private var restorePurchasesRow: some View {
        Button {
            Task {
                await store.restorePurchases()
                let didRestore = settings.hasRemovedAds || settings.isSubscribed
                    || settings.isFantasyUnlocked || settings.isPrehistoricUnlocked || settings.isMythicUnlocked
                restoreMessage = didRestore
                    ? "Your purchases have been restored!"
                    : "No previous purchases found."
                showRestoreAlert = true
            }
        } label: {
            HStack(spacing: isIPad ? 12 : 10) {
                ZStack {
                    RetroPanelShape(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 50 : 40, height: isIPad ? 50 : 40)
                    Image(systemName: "arrow.clockwise").foregroundColor(Kids.ink).font(.system(size: isIPad ? 20 : 16, weight: .bold))
                }
                Text("Restore purchases")
                    .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                    .foregroundColor(Kids.ink)
                Spacer()
                if store.isPurchasing {
                    ProgressView().tint(Kids.ink)
                } else {
                    Text("›").font(Kids.fredoka(isIPad ? 26 : 22, weight: .bold)).foregroundColor(Kids.inkSoft)
                }
            }
            .padding(.horizontal, isIPad ? 18 : 14).padding(.vertical, isIPad ? 14 : 10)
            .background(KidsSettingsCard())
            .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    // MARK: - Subscription management + Apple footnote

    private var legalFooter: some View {
        VStack(spacing: isIPad ? 10 : 8) {
            // Leaves the app — parental gate first (Kids Category requirement).
            Button("Manage Subscriptions") {
                HapticsService.shared.tap()
                requireParentGate {
                    if let u = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(u)
                    }
                }
            }
            .buttonStyle(.plain)
            .font(Kids.fredoka(isIPad ? 14 : 12, weight: .bold))
            .foregroundColor(Kids.grapeDeep)

            Text("All purchases are processed by Apple.\nSubscriptions renew automatically unless cancelled.")
                .font(Kids.nunito(isIPad ? 12 : 10, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, isIPad ? 10 : 6)
    }
}

// MARK: - Shared building blocks (file-scoped)

/// The standard white sticker card background used across Settings + Shop.
struct KidsSettingsCard: View {
    var body: some View {
        RetroPanelShape(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
    }
}

/// Big friendly door row: tinted emoji tile + title/subtitle + chevron/lock.
struct KidsNavRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let tint: Color
    var isIPad: Bool = false
    var lock: Bool = false

    var body: some View {
        HStack(spacing: isIPad ? 14 : 12) {
            ZStack {
                RetroPanelShape(cornerRadius: 14, style: .continuous)
                    .fill(tint)
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    .frame(width: isIPad ? 56 : 46, height: isIPad ? 56 : 46)
                RetroSymbol(emoji, size: isIPad ? 28 : 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text(subtitle)
                    .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Image(systemName: lock ? "lock.fill" : "chevron.right")
                .font(.system(size: isIPad ? 20 : 17, weight: .bold))
                .foregroundColor(Kids.inkSoft)
        }
        .padding(isIPad ? 16 : 13)
        .background(KidsSettingsCard())
        .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
    }
}

/// Full-width purchase CTA in the sticker style. The parental gate is applied
/// by the CALLER (wrap the action) so gating stays visible at each call site.
struct KidsPurchaseButton: View {
    let label: String
    let color: Color
    var isIPad: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticsService.shared.tap()
            action()
        }) {
            Text(label)
                .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                .foregroundColor(Kids.ink)
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 54 : 44)
                .background(
                    RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .fill(color)
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                )
                .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

private struct StatChip: View {
    let icon: String
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            RetroSymbol(icon, size: 10)
            Text(label)
                .font(Kids.fredoka(10, weight: .bold))
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(
            RetroPanelShape().fill(color)
                .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
        )
    }
}

private struct SettingRow: View {
    let icon: String
    let bg: Color
    let label: String
    let value: String
    var toggle: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RetroPanelShape(cornerRadius: 12, style: .continuous)
                    .fill(bg)
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    .frame(width: 40, height: 40)
                RetroSymbol(icon, size: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Kids.fredoka(15, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text(value)
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            Spacer()
            if let t = toggle { KidToggle(isOn: t) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RetroPanelShape(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
    }
}
