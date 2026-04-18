import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coinStore = CoinStore.shared
    @StateObject private var store = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showStoreAlert = false
    @State private var showGameCenterSignInAlert = false
    @ObservedObject private var gc = GameCenterManager.shared

    var body: some View {
        ZStack {
            ScreenBackground(style: .settings).ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                ZStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(.ultraThinMaterial))
                                .overlay(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    VStack(spacing: 2) {
                        Text("⚙️")
                            .font(.system(size: 24))
                        Text("SETTINGS")
                            .font(Theme.bungee(18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: Coins section
                        settingsSection(title: "BATTLE COINS") {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Battle Coins")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Earn by playing · Spend to unlock")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                Spacer()
                                CoinBadge(size: .large)
                            }
                            .padding(.vertical, 4)

                            Divider().background(Color.white.opacity(0.1))

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    coinEarnRow(amount: "10", label: "per battle")
                                    coinEarnRow(amount: "+25", label: "first battle each day (bonus)")
                                    coinEarnRow(amount: "75", label: "per ad (up to 8/day)")
                                }
                                Spacer()
                                if !settings.isSubscribed {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("👑 Premium")
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundColor(Color(hex: "#FFD700"))
                                        Text("earns 2× coins!")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        // MARK: Coin Bank
                        settingsSection(title: "🏦  COIN BANK") {
                            VStack(spacing: 14) {
                                HStack(spacing: 12) {
                                    GoldCoin(size: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Buy Coins")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("Instant top-up — never runs out")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                purchaseButton(
                                    label: store.coins1000Product.map { "1,000 Coins — \($0.displayPrice)" } ?? "1,000 Coins — $1.99",
                                    gradient: LinearGradient(colors: [Color(hex: "#DAA520"), Color(hex: "#B8860B")], startPoint: .leading, endPoint: .trailing),
                                    shadowColor: Color(hex: "#DAA520")
                                ) {
                                    Task {
                                        // If ASC didn't return the product at
                                        // launch, reload now — then try the
                                        // purchase. Only alert if still missing.
                                        if store.coins1000Product == nil {
                                            await store.loadProducts()
                                        }
                                        if let product = store.coins1000Product {
                                            await store.purchase(product)
                                        } else {
                                            showStoreAlert = true
                                        }
                                    }
                                }
                                Text("Coins are added instantly to your balance and never expire.")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 4)
                        }

                        // MARK: Appearance
                        settingsSection(title: "🎨  APPEARANCE") {
                            settingsToggle(
                                icon: "sun.max.fill",
                                iconColor: Theme.yellow,
                                title: "Light Mode",
                                subtitle: "Switch to a lighter theme",
                                isOn: $settings.isLightMode
                            )
                        }

                        // MARK: Sound & Haptics
                        settingsSection(title: "🔊  SOUND & VIBRATION") {
                            settingsToggle(
                                icon: "speaker.wave.2.fill",
                                iconColor: Theme.cyan,
                                title: "Sound Effects",
                                subtitle: "Battle sounds and music",
                                isOn: $settings.soundEnabled
                            )
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggle(
                                icon: "waveform",
                                iconColor: Theme.teal,
                                title: "Narration",
                                subtitle: "Read battle results aloud",
                                isOn: $settings.narrationEnabled
                            )
                            Divider().background(Color.white.opacity(0.1))
                            settingsToggle(
                                icon: "iphone.radiowaves.left.and.right",
                                iconColor: Theme.purple,
                                title: "Haptics",
                                subtitle: "Vibration feedback",
                                isOn: $settings.hapticsEnabled
                            )
                        }

                        // MARK: Creature Packs
                        settingsSection(title: "🦖  PREHISTORIC PACK") {
                            if settings.isPrehistoricUnlocked {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 22)).foregroundColor(Color(hex: "#C8820A"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Prehistoric Pack Unlocked")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("12 ancient titans ready to battle")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 20)).foregroundColor(Color(hex: "#C8820A"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Prehistoric Pack")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("T-Rex, Megalodon, Mammoth + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                    }
                                    purchaseButton(
                                        label: store.prehistoricPackProduct.map { "Prehistoric Pack — \($0.displayPrice)" } ?? "Prehistoric Pack — $1.99",
                                        gradient: LinearGradient(colors: [Color(hex: "#C8820A"), Color(hex: "#8B5A0A")], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Color(hex: "#C8820A")
                                    ) {
                                        Task {
                                            if let product = store.prehistoricPackProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.prehistoricUnlocked = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        settingsSection(title: "🧚  FANTASY PACK") {
                            if settings.fantasyUnlocked {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 22)).foregroundColor(Color(hex: "#7B5EA7"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Fantasy Pack Unlocked")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("12 magical creatures ready to battle")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 20)).foregroundColor(Color(hex: "#7B5EA7"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Fantasy Pack")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("Dragon, Unicorn, Phoenix + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                    }
                                    purchaseButton(
                                        label: store.fantasyPackProduct.map { "Fantasy Pack — \($0.displayPrice)" } ?? "Fantasy Pack — $1.99",
                                        gradient: LinearGradient(colors: [Color(hex: "#7B5EA7"), Color(hex: "#4A3570")], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Color(hex: "#7B5EA7")
                                    ) {
                                        Task {
                                            if let product = store.fantasyPackProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.fantasyUnlocked = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        settingsSection(title: "⚡  MYTHIC BEASTS PACK") {
                            if settings.isMythicUnlocked {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 22)).foregroundColor(Color(hex: "#C0A000"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Mythic Beasts Pack Unlocked")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("12 legendary creatures from ancient myth")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 20)).foregroundColor(Color(hex: "#C0A000"))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Mythic Beasts Pack")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("Thunderbird, Manticore, Roc + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                    }
                                    purchaseButton(
                                        label: store.mythicPackProduct.map { "Mythic Beasts Pack — \($0.displayPrice)" } ?? "Mythic Beasts Pack — $2.99",
                                        gradient: LinearGradient(colors: [Color(hex: "#C0A000"), Color(hex: "#7A6600")], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Color(hex: "#C0A000")
                                    ) {
                                        Task {
                                            if let product = store.mythicPackProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.mythicUnlocked = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // MARK: Remove Ads
                        settingsSection(title: "🚫  REMOVE ADS") {
                            if settings.hasRemovedAds {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Theme.teal)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ads Removed")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("Thank you for your support!")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 14) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Remove Ads")
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("One-time purchase — no more ads, ever")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                    }

                                    purchaseButton(
                                        label: store.removeAdsProduct.map { "Remove Ads — \($0.displayPrice)" } ?? "Remove Ads — $4.99",
                                        gradient: LinearGradient(colors: [Theme.orange, Theme.yellow], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Theme.orange
                                    ) {
                                        Task {
                                            if let product = store.removeAdsProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.hasRemovedAds = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // MARK: Premium
                        settingsSection(title: "✨  PREMIUM") {
                            if settings.isSubscribed {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Theme.gold)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Premium Active")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("All features unlocked")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 14) {
                                    // Feature list
                                    VStack(alignment: .leading, spacing: 8) {
                                        premiumFeature("No ads — ever")
                                        premiumFeature("Unlimited custom fighters")
                                        premiumFeature("All 3 creature packs unlocked")
                                        premiumFeature("Priority battle results")
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 4)

                                    // Monthly button
                                    purchaseButton(
                                        label: store.premiumMonthlyProduct.map { "Monthly — \($0.displayPrice)/mo" } ?? "Monthly — $2.99/mo",
                                        gradient: LinearGradient(colors: [Theme.purple, Theme.cyan], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Theme.purple
                                    ) {
                                        Task {
                                            if let product = store.premiumMonthlyProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.isSubscribed = true
                                                settings.hasRemovedAds = true
                                                settings.fantasyUnlocked = true
                                                settings.prehistoricUnlocked = true
                                                settings.mythicUnlocked = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }

                                    // Annual button
                                    purchaseButton(
                                        label: store.premiumAnnualProduct.map { "Annual — \($0.displayPrice)/yr" } ?? "Annual — $19.99/yr",
                                        gradient: LinearGradient(colors: [Theme.gold, Theme.orange], startPoint: .leading, endPoint: .trailing),
                                        shadowColor: Theme.gold,
                                        badge: "BEST VALUE"
                                    ) {
                                        Task {
                                            if let product = store.premiumAnnualProduct {
                                                await store.purchase(product)
                                            } else {
                                                #if DEBUG
                                                settings.isSubscribed = true
                                                settings.hasRemovedAds = true
                                                settings.fantasyUnlocked = true
                                                settings.prehistoricUnlocked = true
                                                settings.mythicUnlocked = true
                                                #else
                                                await store.loadProducts()
                                                showStoreAlert = true
                                                #endif
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // MARK: Restore
                        settingsSection(title: "🔄  PURCHASES") {
                            Button {
                                Task {
                                    await store.restorePurchases()
                                    let didRestore = settings.hasRemovedAds || settings.isSubscribed
                                    restoreMessage = didRestore
                                        ? "Your purchases have been restored!"
                                        : "No previous purchases found."
                                    showRestoreAlert = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("RESTORE PURCHASES")
                                        .font(Theme.bungee(13))
                                        .tracking(1)
                                    Spacer()
                                    if store.isPurchasing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isPurchasing)
                        }

                        // MARK: Game Center
                        settingsSection(title: "🏆  GAME CENTER") {
                            VStack(spacing: 14) {
                                if !gc.isAuthenticated {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(Theme.gold)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Sign in to Game Center in iOS Settings to unlock achievements and leaderboards.")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.8))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.gold.opacity(0.12)))
                                }
                                Button {
                                    if gc.isAuthenticated {
                                        // Queue the GC screen and dismiss Settings —
                                        // HomeView's sheet(onDismiss:) will flush and
                                        // present once Settings has fully animated out.
                                        GameCenterManager.shared.pendingAction = .achievements
                                        dismiss()
                                    } else { showGameCenterSignInAlert = true }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Theme.teal.opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "trophy.fill")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.teal)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Achievements")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("76 achievements to unlock!")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider().background(Color.white.opacity(0.1))

                                Button {
                                    if gc.isAuthenticated {
                                        GameCenterManager.shared.pendingAction = .leaderboards
                                        dismiss()
                                    } else { showGameCenterSignInAlert = true }
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Theme.orange.opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "chart.bar.fill")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Theme.orange)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Leaderboards")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                            Text("See how you rank worldwide!")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: About
                        settingsSection(title: "ℹ️  ABOUT") {
                            VStack(spacing: 14) {
                                aboutRow(label: "Version", value: {
                                    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                                    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                                    return "\(v) (\(b))"
                                }())
                                Divider().background(Color.white.opacity(0.1))
                                aboutRow(label: "Battles fought", value: "\(settings.totalBattleCount)")
                            }
                            .padding(.horizontal, 4)
                        }

                        Text("All purchases are processed by Apple.\nSubscriptions renew automatically unless cancelled.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        // Manage Subscriptions — required by Apple for apps with auto-renewable subs
                        Link("Manage Subscriptions", destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.orange)

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: URL(string: "https://animal-vs-animal.com/privacy.html")!)
                            Text("·").foregroundColor(.white.opacity(0.35))
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Text("·").foregroundColor(.white.opacity(0.35))
                            Link("Support", destination: URL(string: "https://animal-vs-animal.com/support.html")!)
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.orange)
                        .padding(.bottom, 40)

                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .preferredColorScheme(settings.isLightMode ? .light : .dark)
        .alert("Restore Purchases", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        .alert("Store Unavailable", isPresented: $showStoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't load products. Please check your connection and try again.")
        }
        .alert("Sign in to Game Center", isPresented: $showGameCenterSignInAlert) {
            Button("Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("You're not signed into Game Center yet. Open iOS Settings → Game Center to sign in, then come back to unlock achievements and leaderboards.")
        }
    }

    // MARK: - Sub-views

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.bungee(11))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1.5)

            VStack(spacing: 14) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1))
            )
        }
    }

    private func settingsToggle(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(iconColor)
                .onChange(of: isOn.wrappedValue) { _ in
                    HapticsService.shared.tap()
                }
        }
    }

    private func premiumFeature(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.teal)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func purchaseButton(
        label: String,
        gradient: LinearGradient,
        shadowColor: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                HStack {
                    Text(label)
                        .font(Theme.bungee(14))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let badge = badge {
                    HStack {
                        Spacer()
                        Text(badge)
                            .font(Theme.bungee(10))
                            .foregroundColor(Color(hex: "#190F40"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white))
                    }
                    .padding(.trailing, 12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 14).fill(gradient))
            .shadow(color: shadowColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(store.isPurchasing)
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func coinEarnRow(amount: String, label: String) -> some View {
        HStack(spacing: 6) {
            GoldCoin(size: 14)
            Text(amount)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "#FFD700"))
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    SettingsView()
}
