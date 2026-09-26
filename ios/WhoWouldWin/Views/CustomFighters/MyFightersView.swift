import SwiftUI

/// The library remains useful offline and after creation eligibility expires.
/// Account actions and sending a name to the provider each have a fresh parent gate.
struct MyFightersView: View {
    var unavailableIDs: Set<String> = []
    var onSelect: ((Animal) -> Void)? = nil
    @ObservedObject private var account = CustomFighterAccount.shared
    @ObservedObject private var service = CustomFighterService.shared
    @ObservedObject private var library = CustomFighterLibraryStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var name = ""
    @FocusState private var nameFocused: Bool
    @State private var showAccount = false
    @State private var showShop = false
    @State private var showParentGate = false
    @State private var showProviderConfirmation = false
    @State private var gatedAction: (() -> Void)?
    @State private var preview: CustomFighter?
    @State private var remoteToDelete: CustomFighter?

    private var downloadable: [RemoteCustomFighter] {
        service.remoteFighters.filter { remote in !library.fighters.contains { $0.id == remote.id && $0.appearance == remote.appearance } }
    }
    private var nameIsValid: Bool { (try? CustomFighterService.validatedName(name)) != nil }

    var body: some View {
        ZStack {
            SkyBG(variant: .meadow)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("MY FIGHTERS").font(Kids.fredoka(25)).foregroundColor(Kids.ink)
                        Spacer()
                        KidIconBtn(icon: "✕", fill: .white, a11yLabel: "Close My Fighters") { dismiss() }
                            .accessibilityIdentifier("myFighters.close")
                    }
                    Text("Keep your own creatures ready for the arena.")
                        .font(Kids.nunito(15)).foregroundColor(Kids.inkSoft)
                    #if DEBUG
                    if service.isUITestFixture {
                        Text("TEST artwork requests: \(service.fixtureCreateCount)")
                            .font(.system(size: 11, design: .monospaced))
                            .accessibilityIdentifier("myFighters.fixtureRequestCount")
                    }
                    #endif
                    accountCard
                    creationCard
                    if let message = service.message {
                        Text(message).font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.ink)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Kids.sun.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("myFighters.message")
                    }
                    if service.hasUnconfirmedRequest {
                        Button("Resume saved request") { service.resumeRequest() }
                            .buttonStyle(.borderedProminent).tint(Kids.grassDeep)
                            .disabled(service.isCreating)
                            .accessibilityIdentifier("myFighters.resume")
                        Text("This checks the same request; it does not spend a second credit.")
                            .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                    }
                    if !service.jobs.isEmpty { jobsSection }
                    HStack {
                        Text("SAVED FIGHTERS").font(Kids.fredoka(19)).foregroundColor(Kids.ink)
                        Spacer()
                        Button {
                            Task { await service.refresh() }
                        } label: {
                            if service.isRefreshing { ProgressView() }
                            else { Label("Refresh", systemImage: "arrow.clockwise") }
                        }
                        .font(Kids.nunito(13, weight: .bold)).foregroundColor(Kids.grassDeep)
                        .frame(minHeight: 44).disabled(service.isRefreshing)
                        .accessibilityIdentifier("myFighters.refresh")
                    }
                    if library.fighters.isEmpty && downloadable.isEmpty {
                        Text(account.isSignedIn ? "No saved artwork yet. Your existing typed-name creatures still work in the fighter picker." : "Sign in with a grown-up to restore saved artwork or create a new fighter. Existing typed-name creatures still work in the picker.")
                            .font(Kids.nunito(15)).foregroundColor(Kids.inkSoft)
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityIdentifier("myFighters.empty")
                    }
                    ForEach(library.fighters) { fighter in installedRow(fighter) }
                    ForEach(downloadable) { remote in downloadRow(remote) }
                    Text("Downloaded fighters stay playable offline and after Premium ends. Creating artwork has a separate monthly allowance; existing local custom-creature benefits are unchanged.")
                        .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                    Color.clear.frame(height: 12)
                }
                .padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
        }
        .task { await service.refresh() }
        .onChange(of: scenePhase) { phase in if phase == .active { Task { await service.refresh() } } }
        .parentGate(isPresented: $showParentGate) { let action = gatedAction; gatedAction = nil; action?() }
        .sheet(isPresented: $showAccount) { CustomFighterAccountView(onSignedIn: { Task { await service.refresh() } }) }
        .fullScreenCover(isPresented: $showShop) { KidsShopView() }
        .sheet(item: $preview) { fighter in
            CustomFighterDetailView(fighter: fighter, canSelect: onSelect != nil && !unavailableIDs.contains(fighter.animal.id)) {
                choose(fighter)
            }
        }
        .confirmationDialog("Delete this saved fighter?", isPresented: Binding(get: { remoteToDelete != nil }, set: { if !$0 { remoteToDelete = nil } }), titleVisibility: .visible) {
            if let fighter = remoteToDelete {
                Button("Delete from account", role: .destructive) { Task { await service.delete(fighter) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the fighter from your account. It does not restore an artwork credit.") }
        .confirmationDialog("Create artwork with OpenAI?", isPresented: $showProviderConfirmation, titleVisibility: .visible) {
            Button("Create artwork — use 1 credit") { service.create(name: name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The creature name ‘\(name)’ will be sent through our server to OpenAI to draw four poses. Use a fictional creature name, not a child's name or personal details. A successful creation uses one monthly artwork credit. Failed or rejected creations do not use a credit. Saved fighters stay available after Premium ends.")
        }
    }

    private var accountCard: some View {
        Button {
            gate { showAccount = true }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle").font(.system(size: 28)).foregroundColor(Kids.grassDeep)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.isSignedIn ? "Fighter account" : "Sign in with a grown-up").font(Kids.fredoka(18))
                    Text(account.isSignedIn ? "Manage sign-in and saved artwork" : "Restore your library on this device")
                        .font(Kids.nunito(13)).foregroundColor(Kids.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }.foregroundColor(Kids.ink).padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier("myFighters.account")
    }

    private var creationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CREATE A FIGHTER").font(Kids.fredoka(19)).foregroundColor(Kids.ink)
            if let allowance = service.status?.allowance, service.status?.activeSubscription == true {
                Text("\(allowance.remaining) of \(allowance.limit) artwork credits available this month")
                    .font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.grassDeep)
                if allowance.reserved > 0 {
                    Text("\(allowance.reserved) credit reserved while artwork is being checked.")
                        .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                }
            } else {
                Text("Premium includes up to \(service.status?.monthlyAllowance ?? 3) new artwork creations per month during the beta.")
                    .font(Kids.nunito(14)).foregroundColor(Kids.inkSoft)
            }
            TextField("Creature name, e.g. Moon Dragon", text: $name)
                .font(Kids.nunito(16)).foregroundColor(Kids.ink)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .focused($nameFocused).submitLabel(.done).onSubmit { nameFocused = false }
                .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("myFighters.name")
            Text("1–24 characters. Typing does not send a request.")
                .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
            KidButton(title: service.isCreating ? "SENDING REQUEST…" : "CREATE ARTWORK", icon: "✨", color: service.canCreate && nameIsValid ? Kids.grass : Kids.panel, size: .md) {
                nameFocused = false
                gate { showProviderConfirmation = true }
            }
            .disabled(!service.canCreate || !nameIsValid)
            .accessibilityIdentifier("myFighters.create")
            if service.status?.enabled == false || service.status?.configured == false {
                Text("New artwork is temporarily unavailable. You can still use saved fighters.")
                    .font(Kids.nunito(13, weight: .bold)).foregroundColor(Kids.inkSoft)
            } else if account.isSignedIn && service.status?.activeSubscription == false {
                Button("View Premium options") { showShop = true }
                    .font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.grassDeep).frame(minHeight: 44)
                    .accessibilityIdentifier("myFighters.premium")
            }
            Text("A grown-up confirms before the name is sent to OpenAI. You can close this screen while a request finishes.")
                .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
        }.padding(16).background(Kids.mintMist, in: RoundedRectangle(cornerRadius: 16))
    }

    private var jobsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT REQUESTS").font(Kids.fredoka(18)).foregroundColor(Kids.ink)
            ForEach(service.jobs.prefix(5)) { job in
                HStack(spacing: 10) {
                    if job.isActive { ProgressView() }
                    else { Image(systemName: job.state == "ready" ? "checkmark.circle.fill" : "info.circle").foregroundColor(Kids.grassDeep) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.name.isEmpty ? "Artwork request" : job.name).font(Kids.nunito(15, weight: .bold))
                        Text(job.label).font(Kids.nunito(13)).foregroundColor(Kids.inkSoft)
                        if !job.isActive, let code = job.errorCode {
                            Text(CustomFighterRequestFailure(code: code).localizedDescription).font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("myFighters.job.\(job.state)")
            }
        }
    }

    private func installedRow(_ fighter: CustomFighter) -> some View {
        VStack(spacing: 10) {
            Button { preview = fighter } label: {
                HStack(spacing: 12) {
                    RetroCreatureArtwork(animal: fighter.animal, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fighter.name).font(Kids.fredoka(19)).foregroundColor(Kids.ink)
                        Text("Saved on this device · view all four poses").font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundColor(Kids.inkSoft)
                }
            }.buttonStyle(.plain).accessibilityIdentifier("myFighters.preview.\(fighter.id)")
            if onSelect != nil {
                Button(unavailableIDs.contains(fighter.animal.id) ? "Already selected" : "Use fighter") { choose(fighter) }
                    .font(Kids.nunito(15, weight: .heavy)).frame(maxWidth: .infinity, minHeight: 44)
                    .background(Kids.grass, in: RoundedRectangle(cornerRadius: 10)).foregroundColor(Kids.ink)
                    .disabled(unavailableIDs.contains(fighter.animal.id))
                    .accessibilityIdentifier("myFighters.use.\(fighter.id)")
            }
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func downloadRow(_ remote: RemoteCustomFighter) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle").font(.system(size: 27)).foregroundColor(Kids.grassDeep)
            VStack(alignment: .leading, spacing: 4) {
                Text(remote.name).font(Kids.fredoka(18)).foregroundColor(Kids.ink)
                Text("In your account · download to use offline").font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
            }
            Spacer(minLength: 0)
            if service.downloadingIDs.contains(remote.id) { ProgressView() }
            else { Button("Download") { Task { await service.download(remote) } }.font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.grassDeep).frame(minHeight: 44) }
            Menu {
                Button("Report unsafe artwork") { gate { Task { await service.report(remote.fighter, reason: "unsafe") } } }
                Button("Delete from account", role: .destructive) { gate { remoteToDelete = remote.fighter } }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 21)).frame(width: 44, height: 44)
                    .foregroundColor(Kids.grassDeep)
            }.accessibilityLabel("Manage \(remote.name)")
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
    private func gate(_ action: @escaping () -> Void) { gatedAction = action; showParentGate = true }
    private func choose(_ fighter: CustomFighter) {
        guard let onSelect, !unavailableIDs.contains(fighter.animal.id) else { return }
        onSelect(fighter.animal); dismiss()
    }
}

private struct CustomFighterDetailView: View {
    let fighter: CustomFighter
    let canSelect: Bool
    let onSelect: () -> Void
    @ObservedObject private var art = RetroAssetStore.shared
    @ObservedObject private var service = CustomFighterService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showParentGate = false
    @State private var showDelete = false
    @State private var showReport = false
    @State private var gatedAction: (() -> Void)?

    var body: some View {
        ZStack {
            SkyBG(variant: .meadow)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text(fighter.name).font(Kids.fredoka(25)).foregroundColor(Kids.ink)
                        Spacer()
                        KidIconBtn(icon: "✕", fill: .white, a11yLabel: "Close fighter preview") { dismiss() }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(RetroPose.allCases, id: \.rawValue) { pose in
                            VStack(spacing: 8) {
                                if let image = art.image(for: fighter.animal, pose: pose) {
                                    Image(uiImage: image).resizable().interpolation(.none).scaledToFit().frame(height: 125)
                                } else {
                                    Image(systemName: "photo").frame(height: 125).accessibilityLabel("Artwork unavailable")
                                }
                                Text(pose.rawValue.capitalized).font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.ink)
                            }.padding(12).frame(maxWidth: .infinity).background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }.accessibilityIdentifier("myFighters.fourPoses")
                    if canSelect { KidButton(title: "USE FIGHTER", icon: "▶", color: Kids.grass, size: .md) { dismiss(); onSelect() } }
                    Text("Saved artwork can be used without an active subscription. The artwork does not change battle strength or rewards.")
                        .font(Kids.nunito(14)).foregroundColor(Kids.inkSoft)
                    Button("Report artwork") { gate { showReport = true } }
                        .foregroundColor(Kids.grassDeep).frame(minHeight: 44)
                    Button("Delete fighter", role: .destructive) { gate { showDelete = true } }.frame(minHeight: 44)
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }
        }
        .parentGate(isPresented: $showParentGate) { let action = gatedAction; gatedAction = nil; action?() }
        .confirmationDialog("Delete \(fighter.name)?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete from account and this device", role: .destructive) { Task { await service.delete(fighter); dismiss() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the saved fighter. It does not restore a monthly artwork credit.") }
        .confirmationDialog("Report this artwork", isPresented: $showReport, titleVisibility: .visible) {
            Button("Unsafe content") { report("unsafe") }
            Button("Wrong creature") { report("wrong_subject") }
            Button("Poor artwork quality") { report("poor_quality") }
            Button("Other issue") { report("other") }
            Button("Cancel", role: .cancel) {}
        }
    }
    private func gate(_ action: @escaping () -> Void) { gatedAction = action; showParentGate = true }
    private func report(_ reason: String) { Task { await service.report(fighter, reason: reason); dismiss() } }
}
