import SwiftUI

/// Renders an `Animal`'s visual icon — custom pack creature artwork when available,
/// falling back to the creature's emoji. Used throughout the tournament flow, the
/// picker, and anywhere an animal is shown in a list/row.
///
/// Pack creatures (fantasy, mythic, olympus, prehistoric) have bespoke generated
/// artwork loaded via `Animal.creatureAssetName`. Base creatures still use emoji.
struct AnimalAvatar: View {
    let animal: Animal
    /// Bounding side length for the artwork. Emoji is sized to roughly match.
    let size: CGFloat
    /// Corner radius applied when showing custom artwork.
    var cornerRadius: CGFloat = 8

    var body: some View {
        if let assetName = animal.creatureAssetName,
           let img = UIImage(named: assetName) {
            // Built-in pack creature — bundled asset
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else if animal.isCustom, let url = animal.imageURL {
            // Custom creature — use fetched photo, fall back to emoji while loading
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                default:
                    Text(animal.emoji)
                        .font(.system(size: size * 0.75))
                        .frame(width: size, height: size)
                }
            }
        } else {
            // Built-in base creature — emoji
            Text(animal.emoji)
                .font(.system(size: size * 0.85))
                .frame(width: size, height: size)
        }
    }
}
