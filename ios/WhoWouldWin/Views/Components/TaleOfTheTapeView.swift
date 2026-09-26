import SwiftUI

/// "Tale of the Tape" — a side-by-side comparison of the two fighters' real
/// attributes (weight, speed, diet) drawn from the durable AnimalFacts. This is
/// the educational payoff: a kid SEES why the verdict makes sense ("the lion is
/// as heavy as a small car; the mouse weighs less than a grape"). Renders only
/// when BOTH fighters have curated facts (custom creatures have none).
struct TaleOfTheTapeView: View {
    let left: Animal
    let right: Animal

    private var lf: AnimalFact? { AnimalFacts.facts(for: left.id) }
    private var rf: AnimalFact? { AnimalFacts.facts(for: right.id) }

    /// Only worth showing when we have facts for both sides.
    var hasData: Bool { lf != nil && rf != nil }

    var body: some View {
        if let l = lf, let r = rf {
            VStack(spacing: 12) {
                Text("TALE OF THE TAPE")
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .tracking(1)

                // Header row: the two fighters facing off.
                HStack(spacing: 8) {
                    head(left, tint: Kids.sun)
                    Text("VS")
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                    head(right, tint: Kids.peach)
                }

                row("Weight", l.weight, r.weight)
                row("Speed", l.speed, r.speed)
                row("Diet", AnimalFactsSheet.dietPhrase(l.diet), AnimalFactsSheet.dietPhrase(r.diet))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RetroPanelShape(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
        }
    }

    private func head(_ a: Animal, tint: Color) -> some View {
        HStack(spacing: 5) {
            CreatureIcon(animal: a, size: 22)
            Text(a.name.uppercased())
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(RetroPanelShape().fill(tint.opacity(0.6))
            .overlay(RetroPanelShape().stroke(Kids.ink.opacity(0.5), lineWidth: 1.5)))
    }

    /// One stat: a centered label between two tinted value tiles.
    private func row(_ label: String, _ lv: String, _ rv: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            tile(lv, tint: Kids.sun)
            Text(label.uppercased())
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .frame(width: 52)
                .multilineTextAlignment(.center)
            tile(rv, tint: Kids.peach)
        }
    }

    private func tile(_ value: String, tint: Color) -> some View {
        Text(value)
            .font(Kids.nunito(12, weight: .bold))
            .foregroundColor(Kids.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2).minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 6).padding(.vertical, 6)
            .background(
                RetroPanelShape(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.22))
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink.opacity(0.35), lineWidth: 1.5))
            )
    }
}
