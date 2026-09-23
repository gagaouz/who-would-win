import SwiftUI

// MARK: - Animal Arena Jr. Design System
// Kid-friendly sticker aesthetic from design_handoff_animal_arena.
// Signature: chunky ink outlines, hard offset shadows, toy-bright palette,
// Fredoka display + Nunito body fonts.

// MARK: - Color Tokens

enum Kids {

    // Palette (exact hex from handoff)
    static let sun       = Color(hex: "#FFD43B")
    static let sunDeep   = Color(hex: "#FFB800")
    static let sky       = Color(hex: "#5EC8FF")
    static let skyDeep   = Color(hex: "#2BA7E3")
    static let pink      = Color(hex: "#FF7AB8")
    static let pinkDeep  = Color(hex: "#E84A97")
    static let grass     = Color(hex: "#7BD66B")
    static let grassDeep = Color(hex: "#4CB043")
    static let grape     = Color(hex: "#9B6BFF")
    static let grapeDeep = Color(hex: "#7244E8")
    static let peach     = Color(hex: "#FF9A6B")
    static let peachDeep = Color(hex: "#E87340")
    static let cream     = Color(hex: "#FFF6E3")
    static let creamDeep = Color(hex: "#FCEAC1")

    /// The One True Outline & Text color. Never use pure black.
    static let ink       = Color(hex: "#2D1B4E")
    static let inkSoft   = Color(hex: "#574178")

    // MARK: Typography

    /// Fredoka — rounded display font. Used for headlines, sticker words, titles.
    /// Falls back to system rounded if unavailable.
    static func fredoka(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Fredoka", size: size).weight(weight)
    }

    /// Nunito — friendly body font. Used for captions, labels, body copy.
    static func nunito(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Nunito", size: size).weight(weight)
    }

    // MARK: Shadow recipes

    /// The signature offset-only ink shadow — the whole aesthetic depends on this.
    struct InkShadow: ViewModifier {
        var y: CGFloat = 6
        var opacity: Double = 0.22
        var soft: Bool = true
        func body(content: Content) -> some View {
            content
                .shadow(color: Kids.ink.opacity(opacity), radius: 0, x: 0, y: y)
                .shadow(color: soft ? Kids.ink.opacity(0.07) : .clear,
                        radius: soft ? 12 : 0, x: 0, y: soft ? y + 4 : 0)
        }
    }

    /// Plastic-toy sheen — linear white overlay on colored fills.
    static let sheen = LinearGradient(
        colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
        startPoint: .top, endPoint: .init(x: 0.5, y: 0.55)
    )
}

extension View {
    func inkShadow(y: CGFloat = 6, opacity: Double = 0.22, soft: Bool = true) -> some View {
        modifier(Kids.InkShadow(y: y, opacity: opacity, soft: soft))
    }
}

// Color(hex:) is defined elsewhere (Theme.swift) — reuse it.

// MARK: - Sticker fills (ink outline + sheen)

struct StickerShape<S: Shape>: View {
    let shape: S
    var fill: Color
    var strokeWidth: CGFloat = 4
    var body: some View {
        shape
            .fill(fill)
            .overlay(shape.fill(Kids.sheen))
            .overlay(shape.stroke(Kids.ink, lineWidth: strokeWidth))
    }
}

// MARK: - SkyBG — soft three-stop gradient background

struct SkyBG: View {
    enum Variant { case day, sunset, meadow }
    var variant: Variant = .day

    private var colors: [Color] {
        switch variant {
        case .day:     return [Color(hex: "#FFE9A8"), Color(hex: "#FFD1EC"), Color(hex: "#C8E8FF")]
        case .sunset:  return [Color(hex: "#FFC593"), Color(hex: "#FF9FC5"), Color(hex: "#A495F5")]
        case .meadow:  return [Color(hex: "#D4F1A8"), Color(hex: "#FFE9A8"), Color(hex: "#C8E8FF")]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                // TOP-band drifters
                DriftingCloud(w: 120, h: 50, opacity: 0.9,
                              startX: geo.size.width * 0.18, y: 80,
                              drift: 28, duration: 18, phase: 0.0)
                DriftingCloud(w: 90,  h: 38, opacity: 0.85,
                              startX: geo.size.width * 0.82, y: 130,
                              drift: -22, duration: 22, phase: 0.4)
                DriftingCloud(w: 70,  h: 30, opacity: 0.75,
                              startX: geo.size.width * 0.10, y: 200,
                              drift: 32, duration: 26, phase: 0.7)

                // Sparkles (twinkle, not drift)
                TwinkleSparkle(symbol: "✨", size: 14, x: geo.size.width * 0.88, y: 180, phase: 0.0)
                TwinkleSparkle(symbol: "⭐", size: 12, x: geo.size.width * 0.92, y:  80, phase: 0.5)
                TwinkleSparkle(symbol: "✨", size: 10, x: geo.size.width * 0.08, y: 280, phase: 0.9)

                // BOTTOM-band drifters
                DriftingCloud(w: 100, h: 42, opacity: 0.7,
                              startX: geo.size.width * 0.85, y: geo.size.height - 90,
                              drift: -30, duration: 20, phase: 0.2)
                DriftingCloud(w: 80,  h: 34, opacity: 0.6,
                              startX: geo.size.width * 0.18, y: geo.size.height - 60,
                              drift: 26, duration: 24, phase: 0.6)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - DriftingCloud — Cloud + smooth horizontal drift via TimelineView
//
// Uses TimelineView(.animation) so the drift is recomputed every frame from
// the current wall-clock time. Independent of @State (which can reset across
// nav transitions) and doesn't suffer from withAnimation racing onAppear.

struct DriftingCloud: View {
    let w: CGFloat
    let h: CGFloat
    var opacity: Double = 0.9
    let startX: CGFloat
    let y: CGFloat
    /// Horizontal travel amplitude in points. Sign sets initial direction.
    var drift: CGFloat = 24
    /// Seconds for one full out-and-back sway.
    var duration: Double = 18
    /// 0…1 phase offset so multiple clouds don't move in lockstep.
    var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let theta = (t / duration + phase) * 2 * .pi
            let dx = sin(theta) * Double(drift)
            Cloud(w: w, h: h)
                .opacity(opacity)
                .position(x: startX + CGFloat(dx), y: y)
        }
    }
}

// MARK: - TwinkleSparkle — gentle opacity + scale pulse via TimelineView

struct TwinkleSparkle: View {
    let symbol: String
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    var phase: Double = 0
    var period: Double = 2.6

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let theta = (t / period + phase) * 2 * .pi
            // sin sweeps -1…1 → opacity 0.55…1.0 and scale 0.88…1.12
            let s = (sin(theta) + 1) / 2   // 0…1
            Text(symbol)
                .font(.system(size: size))
                .opacity(0.55 + 0.45 * s)
                .scaleEffect(0.88 + 0.24 * s)
                .position(x: x, y: y)
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

struct Cloud: View {
    var w: CGFloat = 100
    var h: CGFloat = 40
    var body: some View {
        ZStack {
            Capsule().fill(Color.white)
            Circle().fill(Color.white).frame(width: h * 1.3, height: h * 1.3).offset(x: -w*0.25)
            Circle().fill(Color.white).frame(width: h * 1.1, height: h * 1.1).offset(x: w*0.22, y: 2)
        }
        .frame(width: w, height: h)
        .overlay(
            Capsule().stroke(Kids.ink, lineWidth: 2.5).frame(width: w, height: h)
        )
    }
}

// MARK: - KidButton — chunky outlined CTA

struct KidButton: View {
    enum Size { case sm, md, lg, xl
        var height: CGFloat { switch self { case .sm: return 44; case .md: return 56; case .lg: return 72; case .xl: return 88 } }
        var fontSize: CGFloat { switch self { case .sm: return 16; case .md: return 20; case .lg: return 26; case .xl: return 32 } }
        var radius: CGFloat { switch self { case .sm: return 16; case .md: return 20; case .lg: return 28; case .xl: return 34 } }
    }

    let title: String
    var icon: String? = nil
    var color: Color = Kids.grass
    var size: Size = .lg
    var action: () -> Void = {}

    @State private var pressed = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Just a gentle bump on iPad — the .xl is already chunky, so 1.1x keeps
    // the touch target friendly without making the button dominate the screen.
    private var scale: CGFloat { sizeClass == .regular ? 1.10 : 1.0 }

    var body: some View {
        let h    = size.height   * scale
        let fs   = size.fontSize * scale
        let r    = size.radius   * scale

        Button(action: action) {
            HStack(spacing: 10 * scale) {
                if let icon { Text(icon).font(.system(size: fs * 0.95)) }
                Text(title)
                    .font(Kids.fredoka(fs, weight: .bold))
                    .tracking(2)                                       // matches StickerWord spacing
                    .foregroundColor(Kids.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(.horizontal, 18 * scale) // keep text away from the rounded corners
            .frame(maxWidth: .infinity)
            .frame(height: h)
            .background(
                StickerShape(shape: RoundedRectangle(cornerRadius: r, style: .continuous), fill: color)
            )
        }
        .buttonStyle(KidButtonPressStyle(y: pressed ? 5 : 0))
    }
}

struct KidButtonPressStyle: ButtonStyle {
    var y: CGFloat = 0
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed
        return configuration.label
            .offset(y: down ? 4 : 0)
            .shadow(color: Kids.ink.opacity(down ? 0.16 : 0.16),
                    radius: 0, x: 0, y: down ? 1 : 4)
            .shadow(color: Kids.ink.opacity(down ? 0.06 : 0.08),
                    radius: down ? 2 : 8, x: 0, y: down ? 2 : 8)
            .animation(.spring(response: 0.12, dampingFraction: 0.5), value: down)
    }
}

// MARK: - AnimalBubble — sticker portrait

struct AnimalBubble: View {
    let emoji: String
    var size: CGFloat = 120
    var tint: Color = Kids.sun
    var tilt: Double = 0
    var selected: Bool = false
    /// Optional bundled asset name (`creature_<id>`). If present in the asset
    /// catalog, renders the real artwork instead of the emoji.
    var assetName: String? = nil
    /// Optional remote image URL — used for custom creatures + Wikipedia photos.
    var imageURL: URL? = nil
    /// Custom (user-typed) creature → renders its searched image, never emoji.
    var isCustom: Bool = false
    /// Display name — lets the custom path self-heal a nil imageURL by re-resolving.
    var animalName: String = ""

    private var bundledImage: UIImage? {
        guard let name = assetName else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        // The inner photo area is `size * 0.74` (13% padding on each side).
        // Photos are explicitly sized to that square and clipped to a Circle
        // of the same diameter so .scaledToFill overflow can't bleed into
        // the white ring — that was the "image escapes the circle" bug.
        let photoSide = size * 0.74

        ZStack {
            // Outer radial ring
            Circle()
                .fill(RadialGradient(colors: [.white, tint], center: .init(x: 0.35, y: 0.3), startRadius: size * 0.1, endRadius: size * 0.6))
                .overlay(Circle().stroke(Kids.ink, lineWidth: 4.5))
            // Inner white disc
            Circle()
                .fill(Color.white)
                .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                .padding(size * 0.11)

            // Photo (bundled or remote) → emoji fallback
            innerContent(photoSide: photoSide)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt))
        .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
        .shadow(color: Kids.ink.opacity(0.05), radius: 8, x: 0, y: 7)
        .overlay(
            Group {
                if selected {
                    Circle().stroke(Color.white, lineWidth: 6)
                        .padding(-6)
                    Circle().stroke(tint, lineWidth: 4)
                        .padding(-12)
                }
            }
        )
    }

    @ViewBuilder
    private func innerContent(photoSide: CGFloat) -> some View {
        if let ui = bundledImage {
            // Built-in animal with a bundled creature_<id> sprite.
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: photoSide, height: photoSide)
                .clipShape(Circle())
        } else if isCustom {
            // Custom creature → always its searched image (never emoji).
            CustomCreatureImage(name: animalName, imageURL: imageURL, side: photoSide)
        } else {
            // Sprite-less built-in (the ~25 core animals) → curated emoji.
            Text(emoji).font(.system(size: size * 0.58))
        }
    }
}

/// The SINGLE render path for a CUSTOM creature's searched image. Resolves the
/// image URL from `imageURL` (or, if nil because of the picker fetch race, by
/// re-resolving from the name — the AnimalImageService cache is keyed by name so
/// it returns the exact same URL the picker showed). While loading or on failure
/// it shows a NEUTRAL placeholder — NEVER an emoji. Built-in animals never use
/// this; they keep their bundled-sprite-or-emoji ladder.
struct CustomCreatureImage: View {
    let name: String
    var imageURL: URL? = nil
    var side: CGFloat
    @State private var resolved: URL? = nil
    /// The AI-cartoon fallback can take 45 s+ to draw a brand-new name and
    /// sometimes fails outright; AsyncImage never retries on its own. Each
    /// bump re-creates ONLY the inner AsyncImage (not this view, so any
    /// animation on the parent bubble is untouched) for another try — by then
    /// the picture is usually ready.
    @State private var attempt = 0

    var body: some View {
        Group {
            if let url = resolved {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        placeholder.task {
                            guard attempt < 2 else { return }
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            guard !Task.isCancelled else { return }
                            attempt += 1
                        }
                    default:
                        placeholder
                    }
                }
                .id(attempt)
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .task(id: name) {
            // Reset first: this view gets REUSED with a new creature (king-of-
            // the-hill swaps fighters in place), and holding the previous URL
            // would flash the old creature's photo under the new name.
            attempt = 0
            resolved = imageURL
            if resolved == nil {
                let url = await AnimalImageService.shared.imageURL(for: name)
                // If the id changed mid-flight this task was cancelled and
                // `url` belongs to the OLD name — never clobber the new
                // task's result with it.
                guard !Task.isCancelled else { return }
                resolved = url
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(hex: "#F7F2FF")
            Image(systemName: "photo")
                .font(.system(size: side * 0.30))
                .foregroundColor(Kids.inkSoft.opacity(0.45))
        }
    }
}

// Convenience that takes a full Animal.
// Render priority: bundled creature_<id> artwork → custom searched image → emoji.
extension AnimalBubble {
    init(animal: Animal, size: CGFloat = 120, tint: Color = Kids.sun,
         tilt: Double = 0, selected: Bool = false) {
        self.init(
            emoji: animal.emoji,
            size: size,
            tint: tint,
            tilt: tilt,
            selected: selected,
            assetName: animal.creatureAssetName,
            imageURL: animal.isCustom ? animal.imageURL : nil,
            isCustom: animal.isCustom,
            animalName: animal.name
        )
    }
}

/// Small inline creature icon: shows the bundled `creature_<id>` sprite when one
/// exists, otherwise the curated emoji. Used in dense spots (Tale of the Tape,
/// Fact of the Day) so creatures that HAVE art show their art instead of an
/// emoji — only the ~25 sprite-less core animals fall back to emoji.
struct CreatureIcon: View {
    let animal: Animal
    var size: CGFloat = 24
    private var bundled: UIImage? {
        guard let name = animal.creatureAssetName else { return nil }
        return UIImage(named: name)
    }
    var body: some View {
        if let ui = bundled {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(animal.emoji).font(.system(size: size * 0.82))
        }
    }
}

/// Emoji-sized creature glyph for dense tournament chips: a custom creature
/// shows its searched photo (never a stand-in emoji); built-ins keep their
/// curated emoji. `size` matches the emoji point size it replaces.
struct CreatureGlyph: View {
    let animal: Animal
    var size: CGFloat
    var body: some View {
        if animal.isCustom {
            CustomCreatureImage(name: animal.name, imageURL: animal.imageURL, side: size * 1.15)
        } else {
            Text(animal.emoji).font(.system(size: size))
        }
    }
}

// MARK: - WinnerSunburst — spinning rays behind a winner

/// A slowly-spinning sunburst of rays radiating from behind a winner — a calmer,
/// recolorable cousin of the tournament champion's rays, so the regular battle
/// and melee winners get the same triumphant backdrop in their own colors.
/// Self-animating and Reduce-Motion-aware (holds still when on). Drop it behind
/// the winner hero (e.g. as the bottom layer of the result ZStack).
struct WinnerSunburst: View {
    var count: Int = 16
    var color: Color = Kids.sun.opacity(0.38)
    /// Vertical position of the rays' origin, as a fraction of height (0 = top).
    var centerY: CGFloat = 0.24
    var lineWidth: CGFloat = 26
    var spinSeconds: Double = 28

    @State private var spin: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height * centerY)
            let r = max(geo.size.width, geo.size.height) * 1.4
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Path { p in
                        let a = Double(i) * (.pi * 2) / Double(count)
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    }
                    .stroke(color, lineWidth: lineWidth)
                }
            }
            .rotationEffect(.degrees(spin), anchor: UnitPoint(x: 0.5, y: centerY))
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: spinSeconds).repeatForever(autoreverses: false)) {
                spin = 360
            }
        }
    }
}

// MARK: - StarSticker — 5-point star (used for "VS")

struct StarSticker: View {
    var text: String = "VS"
    var size: CGFloat = 64
    var fill: Color = Kids.pink

    var body: some View {
        ZStack {
            StarShape(points: 5)
                .fill(fill)
                .overlay(StarShape(points: 5).fill(Kids.sheen))
                .overlay(StarShape(points: 5).stroke(Kids.ink, lineWidth: 3.5))
            Text(text)
                .font(Kids.fredoka(size * 0.32, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Kids.ink, radius: 0, x: 0, y: 2)
        }
        .frame(width: size, height: size)
        .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
    }
}

struct StarShape: Shape {
    var points: Int = 5
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOuter = min(rect.width, rect.height) / 2
        let rInner = rOuter * 0.42
        var path = Path()
        let step = .pi * 2 / Double(points * 2)
        for i in 0..<(points * 2) {
            let a = Double(i) * step - .pi / 2
            let r = i.isMultiple(of: 2) ? rOuter : rInner
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - SpeechBubble — owl mascot tip bubble

struct SpeechBubble<Content: View>: View {
    var tailOnLeft: Bool = true
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: tailOnLeft ? .bottomLeading : .bottomTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Kids.ink, lineWidth: 3.5)
                )
                .shadow(color: Kids.ink.opacity(0.09), radius: 0, x: 0, y: 5)
            content()
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

// MARK: - ProgressPill — cheer meter

struct ProgressPill: View {
    var progress: Double   // 0...1
    var fill: Color = Kids.grass
    var label: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 3))
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().fill(Kids.sheen))
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, progress)))))
                    .padding(3)
                if let label {
                    Text(label).font(Kids.nunito(11, weight: .heavy))
                        .foregroundColor(Kids.ink)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 26)
    }
}

// MARK: - StickerWord — tilted rounded tag used in titles

struct StickerWord: View {
    let text: String
    var fill: Color = Kids.sun
    var fontSize: CGFloat = 46
    var tilt: Double = -3

    var body: some View {
        Text(text)
            .font(Kids.fredoka(fontSize, weight: .bold))
            .tracking(2)
            .foregroundColor(Kids.ink)
            .padding(.horizontal, fontSize * 0.35)
            .padding(.vertical, fontSize * 0.12)
            .background(
                StickerShape(shape: RoundedRectangle(cornerRadius: 22, style: .continuous), fill: fill, strokeWidth: 4.5)
            )
            .rotationEffect(.degrees(tilt))
            .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
            .shadow(color: Kids.ink.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

// MARK: - KidToggle — chunky outlined switch

struct KidToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Kids.grass : Color(hex: "#DCD4E8"))
                    .overlay(Capsule().fill(Kids.sheen))
                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 3))
                    .frame(width: 54, height: 30)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                    .frame(width: 22, height: 22)
                    .shadow(color: Kids.ink.opacity(0.18), radius: 0, x: 0, y: 2)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - KidIconBtn — small square icon button (top nav)

struct KidIconBtn: View {
    let icon: String
    var fill: Color = .white
    var a11yLabel: String? = nil
    var action: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    // VoiceOver reads emoji glyphs literally ("crossing mark", "trophy") or
    // not at all — every icon button needs a real label. Known icons get one
    // automatically; anything novel should pass a11yLabel explicitly.
    private var resolvedLabel: String {
        if let a11yLabel { return a11yLabel }
        switch icon {
        case "←":  return "Back"
        case "✕":  return "Close"
        case "🏆": return "Hall of Fame"
        case "📔": return "Sticker Book"
        case "⚙️": return "Settings"
        default:    return icon
        }
    }

    var body: some View {
        Button(action: action) {
            Text(icon).font(.system(size: isIPad ? 30 : 22))
                .frame(width: isIPad ? 64 : 48, height: isIPad ? 64 : 48)
                .background(
                    StickerShape(shape: RoundedRectangle(cornerRadius: isIPad ? 18 : 14, style: .continuous),
                                 fill: fill, strokeWidth: isIPad ? 4 : 3)
                )
        }
        .buttonStyle(KidButtonPressStyle())
        .accessibilityLabel(resolvedLabel)
    }
}

// MARK: - CoinChip — home top-left

// MARK: - KidsGoldCoin
// Kid-friendly gold coin shape — chunky ink outline + bright gold gradient + sheen.
// Used everywhere instead of the 🪙 emoji so coins read gold on every device.

struct KidsGoldCoin: View {
    var size: CGFloat = 22
    private let goldLight = Color(hex: "#FFE36B")
    private let goldMid   = Color(hex: "#FFC83B")
    private let goldDeep  = Color(hex: "#E8A20A")

    var body: some View {
        ZStack {
            // Outer ink ring
            Circle()
                .fill(LinearGradient(colors: [goldLight, goldDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Kids.ink, lineWidth: max(1.5, size * 0.12)))
            // Inner face
            Circle()
                .fill(LinearGradient(colors: [goldLight, goldMid],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.66, height: size * 0.66)
                .overlay(Circle().stroke(Kids.ink.opacity(0.85), lineWidth: max(1, size * 0.06)))
            // Sheen blob
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: size * 0.32, height: size * 0.18)
                .offset(x: -size * 0.12, y: -size * 0.16)
                .blur(radius: max(0.5, size * 0.02))
            // Dollar/star mark
            Text("★")
                .font(.system(size: size * 0.38, weight: .black))
                .foregroundColor(goldDeep)
        }
        .frame(width: size, height: size)
    }
}

/// Kid-friendly abbreviation for large coin counts so they don't overflow
/// pills and badges. 1_500 → "1.5K", 1_200_000 → "1.2M", 1_000_000_000 → "1B".
/// Values under 1_000 render as-is. Drops trailing `.0` ("12.0M" → "12M").
extension Int {
    var abbreviatedKidsCount: String {
        let n = Double(self)
        let absN = abs(n)
        let (val, suffix): (Double, String)
        switch absN {
        case 1_000_000_000_000...:  (val, suffix) = (n / 1_000_000_000_000, "T")
        case 1_000_000_000...:      (val, suffix) = (n / 1_000_000_000,     "B")
        case 1_000_000...:          (val, suffix) = (n / 1_000_000,         "M")
        case 10_000...:             (val, suffix) = (n / 1_000,             "K")
        default: return "\(self)"
        }
        // Show 1 decimal when < 10 of unit (e.g. "1.5M"), else whole ("12M").
        let formatted: String = abs(val) < 10
            ? String(format: "%.1f", val).replacingOccurrences(of: ".0", with: "")
            : "\(Int(val.rounded()))"
        return formatted + suffix
    }
}

struct CoinChip: View {
    let count: Int
    var action: (() -> Void)? = nil
    @State private var pop: CGFloat = 1
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    var body: some View {
        Button {
            (action ?? { KidsCoinShop.present() })()
        } label: {
            HStack(spacing: isIPad ? 8 : 6) {
                KidsGoldCoin(size: isIPad ? 28 : 22)
                Text(count.abbreviatedKidsCount)
                    .font(Kids.fredoka(isIPad ? 20 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            .padding(.horizontal, isIPad ? 16 : 12).padding(.vertical, isIPad ? 10 : 7)
            .background(
                StickerShape(shape: Capsule(), fill: Kids.sun, strokeWidth: isIPad ? 4 : 3)
            )
            .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
            .scaleEffect(pop)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) coins. Opens the coin shop.")
        .onChange(of: count) { _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) { pop = 1.18 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = 1 }
            }
        }
    }
}

// Coin shop bridge — any CoinChip tap posts a notification that the root view
// observes and uses to present a sheet. Avoids passing a binding through every
// screen that has a coin chip.
enum KidsCoinShop {
    static let openNotification = Notification.Name("KidsCoinShop.open")
    static func present() {
        HapticsService.shared.tap()
        NotificationCenter.default.post(name: openNotification, object: nil)
    }
}

// MARK: - StreakPill

struct StreakPill: View {
    let days: Int
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    var body: some View {
        HStack(spacing: isIPad ? 8 : 6) {
            Text("🔥").font(.system(size: isIPad ? 22 : 16))
            Text("\(days) DAY STREAK!")
                .font(Kids.nunito(isIPad ? 16 : 12, weight: .heavy))
                .tracking(1)
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, isIPad ? 20 : 14).padding(.vertical, isIPad ? 11 : 8)
        .background(
            StickerShape(shape: Capsule(), fill: Kids.peach, strokeWidth: isIPad ? 4 : 3)
        )
        .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
    }
}

// MARK: - Confetti View
// Falling confetti for wins (1v1 result, tournament champion, mystery sticker).
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let xFraction: CGFloat
        let size: CGSize
        let fallDuration: Double
        let delay: Double
        let rotationStart: Double
        let rotationEnd: Double
    }

    private let pieces: [Piece] = {
        let colors: [Color] = [
            Theme.gold, Theme.orange, Theme.purple, Theme.cyan, Theme.teal, Theme.red, .white,
            Color(hex: "#FF69B4"), Color(hex: "#7CFC00"), Color(hex: "#00BFFF")
        ]
        return (0..<55).map { i in
            Piece(
                id: i,
                color: colors[i % colors.count],
                xFraction: CGFloat(i) / 55.0 * 0.92 + 0.04,
                size: CGSize(width: CGFloat.random(in: 7...15), height: CGFloat.random(in: 5...9)),
                fallDuration: Double.random(in: 1.8...3.5),
                delay: Double.random(in: 0...1.4),
                rotationStart: Double.random(in: 0...360),
                rotationEnd: Double.random(in: 400...760)
            )
        }
    }()

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(isAnimating ? piece.rotationEnd : piece.rotationStart))
                    .position(
                        x: piece.xFraction * geo.size.width,
                        y: isAnimating ? geo.size.height + 30 : -20
                    )
                    .opacity(isAnimating ? 0 : 0.9)
                    .animation(
                        .easeIn(duration: piece.fallDuration).delay(piece.delay),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            // Respect Reduce Motion — a screenful of falling, spinning pieces is
            // exactly the large-area motion that setting exists to suppress.
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            // Small delay before triggering so SwiftUI renders positions first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAnimating = true
            }
        }
    }
}
