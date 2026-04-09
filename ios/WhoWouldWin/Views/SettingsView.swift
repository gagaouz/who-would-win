import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @StateObject private var store = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @State private var showStoreAlert = false

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {

                // Header
                ZStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Theme.cardFill))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    VStack(spacing: 2) {
                        Text("⚙️")
                            .font(.system(size: 24))
                        Text("SETTINGS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

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
                            Divider().background(Color.white.opacity(0.08))
                            settingsToggle(
                                icon: "waveform",
                                iconColor: Theme.teal,
                                title: "Narration",
                                subtitle: "Read battle results aloud",
                                isOn: $settings.narrationEnabled
                            )
                            Divider().background(Color.white.opacity(0.08))
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
                                            .foregroundColor(Theme.textPrimary)
                                        Text("12 ancient titans ready to battle")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
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
                                                .foregroundColor(Theme.textPrimary)
                                            Text("T-Rex, Megalodon, Mammoth + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
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
                                            .foregroundColor(Theme.textPrimary)
                                        Text("12 magical creatures ready to battle")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
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
                                                .foregroundColor(Theme.textPrimary)
                                            Text("Dragon, Unicorn, Phoenix + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
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
                                            .foregroundColor(Theme.textPrimary)
                                        Text("12 legendary creatures from ancient myth")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
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
                                                .foregroundColor(Theme.textPrimary)
                                            Text("Thunderbird, Manticore, Roc + 9 more")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
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
                                            .foregroundColor(Theme.textPrimary)
                                        Text("Thank you for your support!")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
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
                                                .foregroundColor(Theme.textPrimary)
                                            Text("One-time purchase — no more ads, ever")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(Theme.textSecondary)
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
                                            .foregroundColor(Theme.textPrimary)
                                        Text("All features unlocked")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(Theme.textSecondary)
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
                                    Text("Restore Purchases")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Spacer()
                                    if store.isPurchasing {
                                        ProgressView().tint(Theme.textPrimary)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                }
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isPurchasing)
                        }

                        // MARK: About
                        settingsSection(title: "ℹ️  ABOUT") {
                            VStack(spacing: 14) {
                                aboutRow(label: "Version", value: {
                                    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                                    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                                    return "\(v) (\(b))"
                                }())
                                Divider().background(Color.white.opacity(0.08))
                                aboutRow(label: "Battles fought", value: "\(settings.totalBattleCount)")
                            }
                            .padding(.horizontal, 4)
                        }

                        Text("All purchases are processed by Apple.\nSubscriptions renew automatically unless cancelled.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        // Manage Subscriptions — required by Apple for apps with auto-renewable subs
                        Link("Manage Subscriptions", destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.orange)

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: URL(string: "https://animal-vs-animal.com/privacy.html")!)
                            Text("·").foregroundColor(Theme.textTertiary)
                            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Text("·").foregroundColor(Theme.textTertiary)
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
    }

    // MARK: - Sub-views

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textTertiary)
                .tracking(1.5)

            VStack(spacing: 14) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1))
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
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
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
                .foregroundColor(Theme.textPrimary)
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
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)

                if let badge = badge {
                    HStack {
                        Spacer()
                        Text(badge)
                            .font(.system(size: 10, weight: .black, design: .rounded))
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
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

#Preview {
    SettingsView()
}
