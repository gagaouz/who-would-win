import SwiftUI
import UIKit

// Compiled in DEBUG + Release (so it's available in TestFlight), but only ever
// surfaced when UserSettings.showDevTools is true — never in App Store builds.

/// A/B harness for the on-device narration experiment.
///
/// Pick two fighters and an arena (or none), tap Compare, and see the
/// **on-device** (Apple Foundation Models) narration next to the **cloud**
/// (Railway + Claude) narration, with latencies. This is the tool for deciding,
/// before any fall release, whether on-device quality is good enough to replace
/// the paid cloud path for tournament/quick battles.
///
/// Reachable from Settings (debug section). Works regardless of the
/// `onDeviceNarrationEnabled` flag — it calls each path directly.
struct NarrationLabView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = UserSettings.shared

    private let pool = Animals.all.filter { !$0.isCustom }

    @State private var f1: Animal = Animals.all.first(where: { $0.id == "lion" }) ?? Animals.all[0]
    @State private var f2: Animal = Animals.all.first(where: { $0.id == "army_ant" }) ?? Animals.all[1]
    /// nil = no arena (vacuum).
    @State private var env: BattleEnvironment? = nil

    @State private var running = false
    @State private var onDevice: LabOutcome? = nil
    @State private var cloud: LabOutcome? = nil

    struct LabOutcome {
        var winnerName: String
        var narration: String
        var funFact: String
        var ms: Int
        var error: String?
    }

    private var availabilityText: String {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            switch OnDeviceNarrator.availability {
            case .available: return "✅ On-device model available"
            case .unavailable(let r): return "⚠️ On-device unavailable — \(r)"
            }
            #else
            return "⚠️ FoundationModels not in this SDK"
            #endif
        } else {
            return "⚠️ Requires iOS 26+ (this OS is older)"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(availabilityText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Experiment flag toggle (so you can flip the live path here too)
                    Toggle("Use on-device for real battles", isOn: $settings.onDeviceNarrationEnabled)
                        .font(.subheadline.weight(.semibold))

                    // Matchup pickers
                    GroupBox("Matchup") {
                        fighterPicker("Fighter 1", selection: $f1)
                        fighterPicker("Fighter 2", selection: $f2)
                        HStack {
                            Text("Arena").font(.subheadline)
                            Spacer()
                            Menu(env?.name ?? "No Arena (vacuum)") {
                                Button("No Arena (vacuum)") { env = nil }
                                ForEach(BattleEnvironment.allCases) { e in
                                    Button(e.name) { env = e }
                                }
                            }
                        }
                        Button {
                            f1 = pool.randomElement() ?? f1
                            f2 = pool.randomElement() ?? f2
                        } label: { Label("Randomize fighters", systemImage: "die.face.5") }
                            .padding(.top, 4)
                    }

                    Button(action: { Task { await compare() } }) {
                        HStack {
                            if running { ProgressView().tint(.white) }
                            Text(running ? "Generating…" : "Compare")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(running ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(running)

                    outcomeCard("📱 On-Device (Apple)", outcome: onDevice, tint: .blue)
                    outcomeCard("☁️ Cloud (Claude)", outcome: cloud, tint: .purple)
                }
                .padding()
            }
            .navigationTitle("Narration Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func fighterPicker(_ label: String, selection: Binding<Animal>) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Menu("\(selection.wrappedValue.emoji) \(selection.wrappedValue.name)") {
                ForEach(pool) { a in
                    Button("\(a.emoji) \(a.name)") { selection.wrappedValue = a }
                }
            }
        }
    }

    @ViewBuilder
    private func outcomeCard(_ title: String, outcome: LabOutcome?, tint: Color) -> some View {
        GroupBox {
            if let o = outcome {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title).font(.headline).foregroundColor(tint)
                        Spacer()
                        Text("\(o.ms) ms").font(.caption.monospaced()).foregroundColor(.secondary)
                        // Copy the full result to the clipboard.
                        Button {
                            let text = o.error.map { "[\(o.winnerName)] ERROR: \($0)" }
                                ?? "Winner: \(o.winnerName)\n\(o.narration)\n\n\(o.funFact)"
                            UIPasteboard.general.string = text
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    if let e = o.error {
                        Text(e).font(.callout).foregroundColor(.orange)
                            .textSelection(.enabled)
                    } else {
                        Text("Winner: \(o.winnerName)").font(.subheadline.weight(.bold))
                        Text(o.narration).font(.body).textSelection(.enabled)
                        Text(o.funFact).font(.callout).foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(title).font(.headline).foregroundColor(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func compare() async {
        running = true
        onDevice = nil
        cloud = nil
        defer { running = false }

        let arenaEnabled = env != nil
        let environment = env ?? .grassland

        // Run both concurrently.
        async let od = runOnDevice(environment: environment, arenaEnabled: arenaEnabled)
        async let cl = runCloud(environment: environment, arenaEnabled: arenaEnabled)
        let (odResult, clResult) = await (od, cl)
        onDevice = odResult
        cloud = clResult
    }

    private func runOnDevice(environment: BattleEnvironment, arenaEnabled: Bool) async -> LabOutcome {
        let start = Date()
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard OnDeviceNarrator.availability.isAvailable else {
                return LabOutcome(winnerName: "—", narration: "", funFact: "", ms: 0,
                                  error: OnDeviceNarrator.availability.reason ?? "unavailable")
            }
            var verdict = OnDeviceResolver.resolve(f1, f2, environment: environment, arenaEffectsEnabled: arenaEnabled)
            if verdict.isDraw {
                verdict = .init(winner: f1, loser: f2, isDraw: false, dominance: 0.55)
            }
            do {
                let story = try await OnDeviceNarrator.shared.narrate(
                    winner: verdict.winner, loser: verdict.loser,
                    environmentName: arenaEnabled ? environment.name : nil)
                return LabOutcome(winnerName: verdict.winner.name,
                                  narration: story.narration, funFact: story.funFact,
                                  ms: Int(Date().timeIntervalSince(start) * 1000), error: nil)
            } catch {
                let raw = "\(error)".lowercased()
                let friendly = (raw.contains("guardrail") || raw.contains("unsafe"))
                    ? "⚠️ Apple's on-device safety filter blocked this matchup. In a real battle this falls back to the cloud automatically, so the kid still gets a story."
                    : error.localizedDescription
                return LabOutcome(winnerName: verdict.winner.name, narration: "", funFact: "",
                                  ms: Int(Date().timeIntervalSince(start) * 1000),
                                  error: friendly)
            }
        }
        #endif
        return LabOutcome(winnerName: "—", narration: "", funFact: "", ms: 0,
                          error: "Requires iOS 26 + FoundationModels")
    }

    private func runCloud(environment: BattleEnvironment, arenaEnabled: Bool) async -> LabOutcome {
        let start = Date()
        do {
            let r = try await BattleService.shared.fetchQuickBattleResult(
                fighter1: f1, fighter2: f2, environment: environment,
                arenaEffectsEnabled: arenaEnabled, forceNetwork: true)
            let winnerName = (r.winner == f1.id) ? f1.name : (r.winner == f2.id ? f2.name : r.winner)
            return LabOutcome(winnerName: winnerName, narration: r.narration, funFact: r.funFact,
                              ms: Int(Date().timeIntervalSince(start) * 1000), error: nil)
        } catch {
            return LabOutcome(winnerName: "—", narration: "", funFact: "", ms: 0,
                              error: error.localizedDescription)
        }
    }
}
