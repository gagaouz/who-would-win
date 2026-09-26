import SwiftUI

/// Durable, real-biology fact card for one creature — the educational payoff
/// parents care about. Opened by tapping a collected sticker in the Sticker
/// Book. Unlike the disposable per-battle AI fun-fact, these facts are
/// persistent and accurate (see AnimalFacts).
struct AnimalFactsSheet: View {
    let animal: Animal
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = UserSettings.shared
    @StateObject private var speech = SpeechService()

    private var fact: AnimalFact? { AnimalFacts.facts(for: animal.id) }
    private var wins: Int { settings.wins(for: animal.id) }

    var body: some View {
        ZStack {
            SkyBG()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        KidIconBtn(icon: "✕", fill: .white) { dismiss() }
                    }
                    .padding(.horizontal, 16).padding(.top, 10)

                    FighterPortrait(animal: animal, size: 140, ringColor: Kids.sun)

                    StickerWord(text: animal.name.uppercased(), fill: Kids.sun,
                                fontSize: 28, tilt: -2)

                    if wins > 0 {
                        Text("🏆 \(wins) win\(wins == 1 ? "" : "s") in your battles")
                            .font(Kids.fredoka(13, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(
                                RetroPanelShape().fill(Kids.peach.opacity(0.9))
                                    .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                            )
                    }

                    if let f = fact {
                        VStack(spacing: 10) {
                            factRow("🍽️", "Diet", Self.dietPhrase(f.diet))
                            factRow("🌍", "Lives in", f.habitat)
                            factRow("⚖️", "Weighs", f.weight)
                            factRow("💨", "Speed", f.speed)
                        }
                        .padding(.horizontal, 18)

                        // The one wow-fact, in a highlighted card.
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DID YOU KNOW?")
                                .font(Kids.fredoka(11, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(RetroPanelShape().fill(Kids.grass).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                            Text(f.coolFact)
                                .font(Kids.nunito(14, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RetroPanelShape(cornerRadius: 20, style: .continuous)
                                .fill(.white)
                                .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                        )
                        .padding(.horizontal, 18)

                        // Read aloud — helps pre-readers.
                        Button {
                            HapticsService.shared.tap()
                            if speech.isSpeaking { speech.stopSpeaking() }
                            else { speech.speak(spokenSummary(f)) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 17, weight: .bold))
                                Text(speech.isSpeaking ? "Stop reading" : "Read it to me!")
                                    .font(Kids.fredoka(15, weight: .bold))
                            }
                            .foregroundColor(Kids.ink)
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(
                                RetroPanelShape().fill(Kids.sky)
                                    .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    } else {
                        Text("Facts for this creature are coming soon!")
                            .font(Kids.nunito(14, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .padding(.top, 20)
                    }

                    Color.clear.frame(height: 30)
                }
            }
        }
        .onDisappear { speech.stopSpeaking() }
    }

    @ViewBuilder
    private func factRow(_ emoji: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            RetroSymbol(emoji, size: 22).frame(width: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(Kids.fredoka(10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                Text(value)
                    .font(Kids.nunito(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RetroPanelShape(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private func spokenSummary(_ f: AnimalFact) -> String {
        "The \(animal.name). \(Self.dietSentence(f.diet)) It lives in \(f.habitat). It weighs \(f.weight). \(f.coolFact)"
    }

    /// Turns the taxonomy label into a kid-readable value: "Carnivore" reads
    /// as "Meat — a meat-eater", not the ungrammatical "Eats: Carnivore".
    static func dietPhrase(_ diet: String) -> String {
        switch diet.lowercased() {
        case "carnivore": return "Meat — a meat-eater"
        case "herbivore": return "Plants — a plant-eater"
        case "omnivore":  return "Plants and meat — an omnivore"
        default:          return diet
        }
    }

    /// Spoken-aloud version: a full sentence.
    static func dietSentence(_ diet: String) -> String {
        switch diet.lowercased() {
        case "carnivore": return "It is a meat-eater."
        case "herbivore": return "It is a plant-eater."
        case "omnivore":  return "It eats both plants and meat."
        default:          return "It eats \(diet)."
        }
    }
}
