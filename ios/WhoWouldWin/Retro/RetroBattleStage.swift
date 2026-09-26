import SwiftUI
import SpriteKit

@MainActor
private final class RetroBattleStageModel: ObservableObject {
    let scene: RetroBattleScene
    @Published var caption = "The challengers are getting ready."

    init(id: UUID, teamA: [Animal], teamB: [Animal], environment: BattleEnvironment) {
        scene = RetroBattleScene(sessionID: id, teamA: teamA, teamB: teamB, environment: environment)
    }
}

/// Shared solo/team/tournament presentation. Every interaction stays a native
/// SwiftUI accessibility element; SpriteKit only draws the arena performance.
struct RetroBattleStage: View {
    let sessionID: UUID
    let teamA: [Animal]
    let teamB: [Animal]
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    let outcome: RetroBattleOutcome?
    var title = "BATTLE ARENA"
    var pickedSide: Int = 0
    var onCheer: ((Int) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    let onComplete: () -> Void

    @StateObject private var model: RetroBattleStageModel
    @ObservedObject private var assets = RetroAssetStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var cheers = [0, 0]

    init(sessionID: UUID, teamA: [Animal], teamB: [Animal], environment: BattleEnvironment,
         arenaEffectsEnabled: Bool, outcome: RetroBattleOutcome?, title: String = "BATTLE ARENA",
         pickedSide: Int = 0, onCheer: ((Int) -> Void)? = nil, onClose: (() -> Void)? = nil,
         onComplete: @escaping () -> Void) {
        self.sessionID = sessionID
        self.teamA = teamA; self.teamB = teamB
        self.environment = environment
        self.arenaEffectsEnabled = arenaEffectsEnabled
        self.outcome = outcome; self.title = title
        self.pickedSide = pickedSide; self.onCheer = onCheer
        self.onClose = onClose; self.onComplete = onComplete
        _model = StateObject(wrappedValue: RetroBattleStageModel(id: sessionID, teamA: teamA, teamB: teamB, environment: environment))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title).font(Kids.pixel(14)).foregroundColor(Kids.ink)
                        Text(arenaEffectsEnabled ? environment.name.uppercased() : "QUICK FIGHT · NO ARENA EFFECTS")
                            .font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                    }
                    Spacer()
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark").font(.system(size: 17, weight: .bold))
                                .frame(width: 44, height: 44)
                        }
                        .foregroundColor(Kids.ink)
                        .accessibilityLabel("Close battle")
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    roster(teamA, label: teamA.count == 1 ? "CHALLENGER 1" : "TEAM A", side: 1)
                    Text("VS").font(Kids.pixel(17)).foregroundColor(Kids.inkSoft).padding(.top, 28)
                    roster(teamB, label: teamB.count == 1 ? "CHALLENGER 2" : "TEAM B", side: 2)
                }
                SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
                    .aspectRatio(480.0 / 280.0, contentMode: .fit)
                    .overlay(Rectangle().stroke(Color(hex: "#314C42"), lineWidth: 3))
                    .shadow(color: Color(hex: "#314C42").opacity(0.2), radius: 0, x: 0, y: 5)
                    .accessibilityHidden(true)
                VStack(spacing: 9) {
                    if outcome == nil {
                        HStack(spacing: 9) {
                            ProgressView().tint(Kids.inkSoft)
                            Text("Getting the battle ready…").font(Kids.nunito(15, weight: .bold))
                        }
                    } else {
                        Text(model.caption).font(Kids.nunito(15, weight: .bold))
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    Text("Cheer for your pick. The crowd never changes the result.")
                        .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft).multilineTextAlignment(.center)
                }
                .foregroundColor(Kids.ink)
                .frame(minHeight: 58)
                HStack(spacing: 12) {
                    cheerButton(side: 1, fighters: teamA)
                    cheerButton(side: 2, fighters: teamB)
                }
                if outcome != nil {
                    Button("Show result") { model.scene.skip() }
                        .font(Kids.nunito(14, weight: .bold)).foregroundColor(Kids.inkSoft)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("battle.skipAnimation")
                } else {
                    Text(teamA.count == 1 && teamB.count == 1
                         ? BattleInsight.matchupPreview(teamA[0], teamB[0]).hype
                         : "Every teammate has a part to play.")
                        .font(Kids.nunito(12)).foregroundColor(Kids.inkSoft)
                        .frame(minHeight: 44)
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(hex: "#F4EDD8"))
        .accessibilityIdentifier("battle.arena")
        .onAppear {
            model.scene.onFinished = onComplete
            model.scene.onCaption = { caption in model.caption = caption }
            model.scene.reduceMotion = reduceMotion
            model.scene.active = scenePhase == .active
            model.scene.accept(outcome)
        }
        .onChange(of: outcome) { value in model.scene.accept(value) }
        .onChange(of: reduceMotion) { value in model.scene.reduceMotion = value }
        .onChange(of: scenePhase) { value in model.scene.active = value == .active }
        .onChange(of: assets.revision) { _ in model.scene.refreshArtwork() }
        .task(id: sessionID) {
            await assets.prepare(teamA + teamB)
            guard !Task.isCancelled else { return }
            model.scene.refreshArtwork()
        }
        .onDisappear { model.scene.stop() }
    }

    private func roster(_ fighters: [Animal], label: String, side: Int) -> some View {
        VStack(spacing: 5) {
            Text(label).font(Kids.nunito(10, weight: .bold)).foregroundColor(Kids.inkSoft)
            HStack(spacing: 2) {
                ForEach(fighters) { animal in
                    RetroCreatureArtwork(animal: animal, size: fighters.count > 2 ? 36 : 48)
                        .accessibilityHidden(true)
                }
            }
            Text(fighters.map(\.name).joined(separator: " + "))
                .font(Kids.nunito(fighters.count > 2 ? 11 : 14, weight: .bold))
                .foregroundColor(Kids.ink).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if pickedSide == side {
                Text("YOUR PICK").font(Kids.nunito(10, weight: .bold)).foregroundColor(Kids.grassDeep)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func cheerButton(side: Int, fighters: [Animal]) -> some View {
        Button {
            cheers[side - 1] += 1
            if let onCheer { onCheer(side) }
            else { SoundService.shared.play(.tap, volume: 0.6); HapticsService.shared.tap() }
        } label: {
            VStack(spacing: 4) {
                Text("CHEER \(fighters.count == 1 ? fighters[0].name.uppercased() : side == 1 ? "TEAM A" : "TEAM B")")
                    .font(Kids.nunito(12, weight: .heavy)).multilineTextAlignment(.center)
                Text(cheers[side - 1] == 0 ? "MAKE SOME NOISE" : "\(cheers[side - 1]) CHEERS")
                    .font(Kids.nunito(10, weight: .bold))
                HStack(spacing: 3) {
                    ForEach(0..<10, id: \.self) { segment in
                        Rectangle().fill(Kids.ink.opacity(segment < min(10, 2 + cheers[side - 1]) ? 0.75 : 0.12))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 10)
                .accessibilityHidden(true)
            }
            .foregroundColor(Kids.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 5)
            .background(side == 1 ? Color(hex: "#EEC56B") : Color(hex: "#CCD3A2"))
            .overlay(Rectangle().stroke(Color(hex: "#495C48"), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("battle.cheer\(side)")
        .accessibilityLabel("Cheer for \(fighters.map(\.name).joined(separator: " and "))")
        .accessibilityValue("\(cheers[side - 1]) cheers")
    }
}
