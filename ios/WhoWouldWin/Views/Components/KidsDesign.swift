import SwiftUI

// Native retro UI. Existing component names remain stable so every game flow
// shares one presentation without changing its state, commerce or navigation.
enum Kids {
    // Miami arcade: sunset pink, turquoise and gold against plum ink.
    // Deep variants are text-safe on the warm card surfaces; bright accents
    // always carry dark labels. These tokens are shared by every game mode.
    static let sun = Color(hex: "#FFD166")
    static let sunDeep = Color(hex: "#754500")
    static let sky = Color(hex: "#69DDD9")
    static let skyDeep = Color(hex: "#0F585F")
    static let pink = Color(hex: "#FF8CB8")
    static let pinkDeep = Color(hex: "#902559")
    static let grass = Color(hex: "#78DBC6")
    static let grassDeep = Color(hex: "#145D56")
    static let grape = Color(hex: "#C5ACF0")
    static let grapeDeep = Color(hex: "#593A7B")
    static let peach = Color(hex: "#FFB08B")
    static let peachDeep = Color(hex: "#7E3B24")
    static let cream = Color(hex: "#FFF1E6")
    static let creamDeep = Color(hex: "#E9D5DE")
    static let panel = Color(hex: "#FFF8EE")
    static let console = Color(hex: "#302046")
    static let ink = Color(hex: "#281E48")
    static let inkSoft = Color(hex: "#584766")
    static let outline = Color(hex: "#BDA6C5")
    static let outlineStrong = Color(hex: "#765C89")
    static let shadow = Color(hex: "#302046")
    static let skyMist = Color(hex: "#E9BADA")
    static let mintMist = Color(hex: "#A5DEDC")
    static let coralMist = Color(hex: "#FFBEA3")

    // Keep the existing call sites' nominal sizes while accounting for the
    // pixel font's wider glyphs. Its single native weight stays crisp; the
    // compatibility weight argument no longer adds synthetic bolding.
    static func fredoka(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("PressStart2P-Regular", size: max(8, size * 0.66), relativeTo: .headline)
    }
    static func nunito(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("PressStart2P-Regular", size: max(8, size * 0.66), relativeTo: .body)
    }
    static func pixel(_ size: CGFloat) -> Font {
        .custom("PressStart2P-Regular", size: size, relativeTo: .headline)
    }
    struct InkShadow: ViewModifier {
        var y: CGFloat = 3
        var opacity: Double = 0.12
        var soft: Bool = true
        func body(content: Content) -> some View {
            content.compositingGroup().shadow(color: Kids.shadow.opacity(opacity), radius: soft ? 6 : 2, x: 0, y: min(y, 4))
        }
    }
    // Kept as a flat token for source compatibility with existing surfaces.
    static let sheen = LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
}

/// Cut corners echo arcade cabinets without the soft pill silhouette. The
/// existing radius argument controls the small diagonal corner cut.
struct RetroPanelShape: InsettableShape {
    var cornerRadius: CGFloat = 10
    var style: RoundedCornerStyle = .continuous
    private var insetAmount: CGFloat = 0

    init(cornerRadius: CGFloat = 10, style: RoundedCornerStyle = .continuous) {
        self.cornerRadius = cornerRadius
        self.style = style
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = max(0, min(6, cornerRadius, min(r.width, r.height) / 2) - insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + cut, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - cut, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + cut))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
        path.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + cut, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - cut))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
        path.closeSubpath()
        return path
    }
    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// Monochrome interface symbols; creature glyphs resolve through real artwork.
struct RetroSymbol: View {
    let glyph: String
    var size: CGFloat = 18
    var color: Color = Kids.ink
    init(_ glyph: String, size: CGFloat = 18, color: Color = Kids.ink) {
        self.glyph = glyph; self.size = size; self.color = color
    }
    private var systemName: String? {
        switch glyph {
        case "←": return "arrow.left"
        case "⌫": return "delete.left.fill"
        case "✕", "✖", "×": return "xmark"
        case "🏆": return "trophy.fill"
        case "📔", "📖", "📚", "📗", "📕", "📘", "📙": return "book.closed.fill"
        case "⚙️": return "gearshape.fill"
        case "🎁": return "gift.fill"
        case "⚡": return "bolt.fill"
        case "⚔️", "🥊": return "bolt.shield.fill"
        case "🎲": return "dice.fill"
        case "❓": return "questionmark.circle"
        case "📅": return "calendar"
        case "✅", "✓": return "checkmark"
        case "🔒": return "lock.fill"
        case "🔓": return "lock.open.fill"
        case "🔥": return "flame.fill"
        case "✨", "⭐", "🌟", "★": return "sparkle"
        case "🌍", "🌎": return "globe.americas.fill"
        case "🌿", "🌳": return "leaf.fill"
        case "📤": return "square.and.arrow.up"
        case "🔊", "🗣️": return "speaker.wave.2.fill"
        case "📳": return "iphone.radiowaves.left.and.right"
        case "▶", "▶️": return "play.fill"
        case "🪙": return "centsign.circle.fill"
        case "👑": return "crown.fill"
        case "🏠": return "house.fill"
        case "🎤": return "mic.fill"
        case "✏️": return "pencil"
        case "🔍": return "magnifyingglass"
        case "🌈": return "square.grid.2x2.fill"
        case "🌊": return "water.waves"
        case "☁️": return "cloud.fill"
        case "🚜": return "leaf.fill"
        case "🔱": return "sparkles"
        case "🎉", "🎊": return "sparkles"
        case "📊": return "chart.bar.fill"
        case "🏅", "🥇", "🥈", "🥉": return "medal.fill"
        case "⚖️": return "scalemass.fill"
        case "🎺", "📣": return "megaphone.fill"
        case "🎙️": return "mic.fill"
        case "🐾": return "pawprint.fill"
        case "🚫": return "nosign"
        case "🔁": return "arrow.clockwise"
        case "🌋": return "mountain.2.fill"
        case "🌙", "🌃": return "moon.stars.fill"
        case "⛈️", "🌩️", "🌪️": return "cloud.bolt.rain.fill"
        case "❄️", "🧊": return "snowflake"
        case "🏜️", "☀️": return "sun.max.fill"
        case "🌴": return "tree.fill"
        case "👏", "🙌": return "hands.clap.fill"
        case "👉": return "arrow.right"
        case "✍️": return "pencil"
        case "🧚", "🪄": return "wand.and.stars"
        case "🏛️": return "building.columns.fill"
        case "🍽️": return "fork.knife"
        case "💨": return "wind"
        case "👋": return "hand.wave.fill"
        case "🐶": return "pawprint.fill"
        case "🌅": return "sunrise.fill"
        case "🎬": return "play.rectangle.fill"
        case "🎯": return "target"
        case "🧝", "🧝‍♂️", "🧝‍♀️": return "person.2.fill"
        case "🔎": return "magnifyingglass"
        case "🧠": return "brain.head.profile"
        case "➕": return "plus"
        case "💎": return "diamond.fill"
        case "❤️", "♥️", "♥": return "heart.fill"
        case "✔", "✔️", "☑️": return "checkmark"
        default: return nil
        }
    }
    var body: some View {
        Group {
            if let systemName {
                Image(systemName: systemName).font(.system(size: size, weight: .bold))
            } else if let animal = Animals.all.first(where: { $0.emoji == glyph }) {
                RetroCreatureArtwork(animal: animal, size: size * 1.25)
            } else if glyph.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) || glyph.contains("\u{FE0F}") {
                Image(systemName: "sparkle").font(.system(size: size, weight: .bold))
            } else {
                Text(glyph).font(Kids.nunito(size, weight: .black))
            }
        }
        .foregroundColor(color)
        .accessibilityHidden(true)
    }
}

extension View {
    func inkShadow(y: CGFloat = 3, opacity: Double = 0.12, soft: Bool = true) -> some View {
        modifier(Kids.InkShadow(y: y, opacity: opacity, soft: soft))
    }

    /// Paragraphs use full-size, scalable book lettering. Pixel type remains
    /// reserved for headings and short arcade labels.
    func readingText(_ style: Font.TextStyle = .body) -> some View {
        modifier(ReadingTextStyle(style: style))
    }
}

private struct ReadingTextStyle: ViewModifier {
    let style: Font.TextStyle
    @ScaledMetric(relativeTo: .body) private var spacing: CGFloat = 5

    func body(content: Content) -> some View {
        content
            .font(.system(style, design: .serif, weight: .regular))
            .lineSpacing(spacing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// Color(hex:) is defined elsewhere (Theme.swift) — reuse it.

// MARK: - Warm surfaces with a fine border and top-edge highlight

struct StickerShape<S: Shape>: View {
    let shape: S
    var fill: Color
    var strokeWidth: CGFloat = 1.5
    var body: some View {
        shape
            .fill(fill)
            .overlay(alignment: .top) {
                shape.stroke(Color.white.opacity(0.75), lineWidth: 1)
                    .padding(1)
                    .mask(Rectangle().frame(height: 8).frame(maxHeight: .infinity, alignment: .top))
            }
            .overlay(shape.stroke(Kids.outlineStrong, lineWidth: strokeWidth))
    }
}

// MARK: - SkyBG — static sunset and arcade horizon, shared across screens

struct SkyBG: View {
    enum Variant { case day, sunset, meadow }
    var variant: Variant = .day
    private var colors: [Color] {
        switch variant {
        case .day: return [Kids.skyMist, Kids.coralMist, Kids.mintMist]
        case .sunset: return [Kids.coralMist, Kids.skyMist, Kids.mintMist]
        case .meadow: return [Kids.mintMist, Kids.skyMist, Kids.coralMist]
        }
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LinearGradient(stops: [
                    .init(color: colors[0], location: 0),
                    .init(color: colors[1], location: 0.52),
                    .init(color: colors[2], location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, size in
                    // Restrained pixel stars and a perspective grid. No motion
                    // behind reading surfaces, and no flashing neon effects.
                    for point in [CGPoint(x: 0.08, y: 0.13), CGPoint(x: 0.91, y: 0.22),
                                  CGPoint(x: 0.04, y: 0.57), CGPoint(x: 0.96, y: 0.73)] {
                        let x = size.width * point.x, y = size.height * point.y
                        var sparkle = Path(CGRect(x: x - 2, y: y - 6, width: 4, height: 12))
                        sparkle.addRect(CGRect(x: x - 6, y: y - 2, width: 12, height: 4))
                        context.fill(sparkle, with: .color(Kids.grapeDeep.opacity(0.16)))
                    }
                    let horizon = size.height * 0.77
                    var grid = Path()
                    for i in -5...5 {
                        grid.move(to: CGPoint(x: size.width * 0.5 + CGFloat(i) * 13, y: horizon))
                        grid.addLine(to: CGPoint(x: size.width * 0.5 + CGFloat(i) * size.width * 0.23, y: size.height))
                    }
                    for fraction in [0.0, 0.12, 0.3, 0.55, 0.9] {
                        let y = horizon + (size.height - horizon) * fraction
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(grid, with: .color(Kids.grapeDeep.opacity(0.12)), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.125, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let theta = (t / duration + phase) * 2 * .pi
            let dx = reduceMotion ? 0 : (sin(theta) * Double(drift) / 2).rounded() * 2
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.125, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let theta = (t / period + phase) * 2 * .pi
            // sin sweeps -1…1 → opacity 0.55…1.0 and scale 0.88…1.12
            let s = reduceMotion ? 1 : (sin(theta) + 1) / 2
            RetroSymbol(symbol, size: size)
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
            Rectangle().fill(Kids.panel).frame(width: w, height: h * 0.45).offset(y: h * 0.2)
            Rectangle().fill(Kids.panel).frame(width: w * 0.65, height: h * 0.55)
            Rectangle().fill(Kids.panel).frame(width: w * 0.28, height: h * 0.35).offset(x: -w * 0.1, y: -h * 0.3)
        }.frame(width: w, height: h).accessibilityHidden(true)
    }
}

// MARK: - KidButton — bright, softly raised action

struct KidButton: View {
    enum Size { case sm, md, lg, xl
        var height: CGFloat { switch self { case .sm: return 44; case .md: return 52; case .lg: return 60; case .xl: return 68 } }
        var fontSize: CGFloat { switch self { case .sm: return 15; case .md: return 18; case .lg: return 20; case .xl: return 22 } }
        var radius: CGFloat { switch self { case .sm: return 8; case .md: return 10; case .lg, .xl: return 12 } }
    }

    let title: String
    var icon: String? = nil
    var color: Color = Kids.grass
    var size: Size = .lg
    var action: () -> Void = {}

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
                if let icon { RetroSymbol(icon, size: fs * 0.78) }
                Text(title)
                    .font(Kids.fredoka(fs, weight: .bold))
                    .tracking(0.2)
                    .foregroundColor(Kids.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18 * scale) // keep text away from the rounded corners
            .frame(maxWidth: .infinity)
            .frame(minHeight: h)
            .background(
                StickerShape(shape: RetroPanelShape(cornerRadius: r, style: .continuous), fill: color)
            )
        }
        .buttonStyle(KidButtonPressStyle())
    }
}

struct KidButtonPressStyle: ButtonStyle {
    var y: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed && !reduceMotion ? 3 : 0)
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(configuration.isPressed ? 0.10 : 0.28),
                    radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
    }
}

// MARK: - AnimalBubble — retro creature portrait

struct AnimalBubble: View {
    let emoji: String
    var size: CGFloat = 120
    var tint: Color = Kids.sun
    var tilt: Double = 0
    var selected: Bool = false
    var assetName: String? = nil
    var imageURL: URL? = nil
    var isCustom: Bool = false
    var animalName: String = ""
    var animal: Animal? = nil

    private var resolvedAnimal: Animal? {
        if let animal { return animal }
        if let assetName, let builtIn = Animals.all.first(where: { $0.creatureAssetName == assetName }) { return builtIn }
        if isCustom {
            return Animal(id: "retro_custom_preview", name: animalName, emoji: emoji, category: .land,
                          pixelColor: "#496845", size: 3, isCustom: true, imageURL: imageURL)
        }
        return Animals.all.first(where: { $0.emoji == emoji })
    }
    var body: some View {
        ZStack {
            RetroPanelShape().fill(Kids.panel)
            RetroPanelShape().fill(tint.opacity(0.20))
            RetroPanelShape().strokeBorder(selected ? Kids.grassDeep : Kids.outline, lineWidth: selected ? 2 : 1)
            if let resolvedAnimal {
                RetroCreatureArtwork(animal: resolvedAnimal, size: size * 0.90)
            } else {
                Image(systemName: "questionmark").font(Kids.pixel(size * 0.22)).foregroundColor(Kids.inkSoft)
            }
        }
        .frame(width: size, height: size)
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.10), radius: 4, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .black))
                    .foregroundColor(Kids.panel).padding(5)
                    .background(RetroPanelShape(cornerRadius: 6).fill(Kids.grassDeep))
            }
        }
    }
}

/// Shared custom-art path for legacy callers. The root artwork provider owns
/// generation/cache/fallback state; presentation never fetches a photo directly.
struct CustomCreatureImage: View {
    let name: String
    var imageURL: URL? = nil
    var side: CGFloat
    var body: some View {
        RetroCreatureArtwork(animal: Animal(id: "retro_custom_preview", name: name, emoji: "", category: .land,
            pixelColor: "#496845", size: 3, isCustom: true, imageURL: imageURL), size: side)
    }
}

extension AnimalBubble {
    init(animal: Animal, size: CGFloat = 120, tint: Color = Kids.sun,
         tilt: Double = 0, selected: Bool = false) {
        self.init(emoji: animal.emoji, size: size, tint: tint, tilt: tilt, selected: selected,
                  assetName: animal.creatureAssetName, imageURL: animal.imageURL,
                  isCustom: animal.isCustom, animalName: animal.name, animal: animal)
    }
}

struct CreatureIcon: View {
    let animal: Animal
    var size: CGFloat = 24
    var body: some View { RetroCreatureArtwork(animal: animal, size: size) }
}

struct CreatureGlyph: View {
    let animal: Animal
    var size: CGFloat
    var body: some View { RetroCreatureArtwork(animal: animal, size: size * 1.15) }
}

// MARK: - WinnerSunburst — static pixel celebration
// Public arguments remain compatible with existing result screens.
struct WinnerSunburst: View {
    var count: Int = 16
    var color: Color = Kids.sun.opacity(0.38)
    var centerY: CGFloat = 0.24
    var lineWidth: CGFloat = 26
    var spinSeconds: Double = 28

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * centerY)
            for i in 0..<max(1, count) {
                let angle = Double(i) * .pi * 2 / Double(max(1, count))
                let radius = size.width * (i.isMultiple(of: 2) ? 0.44 : 0.31)
                let side = max(4, lineWidth * (i.isMultiple(of: 3) ? 0.45 : 0.25))
                let x = (center.x + cos(angle) * radius).rounded()
                let y = (center.y + sin(angle) * radius).rounded()
                context.fill(Path(CGRect(x: x, y: y, width: side, height: side)), with: .color(color))
                if i.isMultiple(of: 3) {
                    context.fill(Path(CGRect(x: x - side, y: y + side, width: side * 3, height: side)), with: .color(color))
                    context.fill(Path(CGRect(x: x, y: y + side * 2, width: side, height: side)), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - StarSticker — compact versus marker

struct StarSticker: View {
    var text: String = "VS"
    var size: CGFloat = 64
    var fill: Color = Kids.sun
    var body: some View {
        ZStack {
            RetroPanelShape().fill(fill)
            RetroPanelShape().strokeBorder(Kids.outlineStrong, lineWidth: 1)
            if text == "VS" {
                Text(text).font(Kids.pixel(size * 0.23)).foregroundColor(Kids.ink)
            } else {
                RetroSymbol(text, size: size * 0.4)
            }
        }.frame(width: size, height: size)
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.12), radius: 3, x: 0, y: 2)
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
            RetroPanelShape(cornerRadius: 24, style: .continuous)
                .fill(Kids.panel)
                .overlay(
                    RetroPanelShape(cornerRadius: 24, style: .continuous)
                        .stroke(Kids.outline, lineWidth: 1.25)
                )
                .compositingGroup().shadow(color: Kids.shadow.opacity(0.09), radius: 6, x: 0, y: 3)
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
                RetroPanelShape()
                    .fill(Kids.cream)
                    .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1))
                RetroPanelShape()
                    .fill(fill)
                    .overlay(RetroPanelShape().fill(Kids.sheen))
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

// MARK: - StickerWord — pixel display title on a small accent tab

struct StickerWord: View {
    let text: String
    var fill: Color = Kids.sun
    var fontSize: CGFloat = 46
    var tilt: Double = -3
    var body: some View {
        Text(text)
            .font(Kids.pixel(max(10, fontSize * 0.56)))
            .lineSpacing(5)
            .foregroundColor(Kids.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, max(12, fontSize * 0.24))
            .padding(.vertical, max(10, fontSize * 0.18))
            .background(RetroPanelShape().fill(fill))
            .overlay(RetroPanelShape().strokeBorder(Kids.outlineStrong.opacity(0.65), lineWidth: 1))
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.10), radius: 4, x: 0, y: 2)
    }
}

// MARK: - KidToggle — clear on/off states with a comfortable touch target

struct KidToggle: View {
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RetroPanelShape()
                    .fill(isOn ? Kids.grass : Kids.creamDeep)
                    .overlay(RetroPanelShape().fill(Kids.sheen))
                    .overlay(RetroPanelShape().stroke(Kids.outlineStrong, lineWidth: 1))
                    .frame(width: 54, height: 30)
                RetroPanelShape(cornerRadius: 6)
                    .fill(Kids.panel)
                    .overlay(RetroPanelShape(cornerRadius: 6).stroke(Kids.outline, lineWidth: 0.75))
                    .frame(width: 22, height: 22)
                    .compositingGroup().shadow(color: Kids.shadow.opacity(0.16), radius: 2, x: 0, y: 1)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .accessibilityValue(isOn ? "On" : "Off")
        .frame(minWidth: 54, minHeight: 44)
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
            RetroSymbol(icon, size: isIPad ? 25 : 20)
                .frame(width: isIPad ? 64 : 48, height: isIPad ? 64 : 48)
                .background(
                    StickerShape(shape: RetroPanelShape(cornerRadius: isIPad ? 18 : 14, style: .continuous),
                                 fill: fill, strokeWidth: 1.25)
                )
        }
        .buttonStyle(KidButtonPressStyle())
        .accessibilityLabel(resolvedLabel)
    }
}

// MARK: - CoinChip — home top-left

// MARK: - KidsGoldCoin
// Small gold token with a pixel glint.
// Used everywhere instead of the 🪙 emoji so coins read gold on every device.

struct KidsGoldCoin: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            RetroPanelShape(cornerRadius: size * 0.8).fill(Kids.sun)
            RetroPanelShape(cornerRadius: size * 0.8).strokeBorder(Kids.peachDeep, lineWidth: max(1, size * 0.08))
            Rectangle().fill(Kids.sunDeep).frame(width: max(2, size * 0.13), height: size * 0.48)
            Rectangle().fill(Kids.panel).frame(width: max(2, size * 0.10), height: size * 0.30).offset(x: -size * 0.24)
        }.frame(width: size, height: size).accessibilityHidden(true)
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
    @State private var popTask: Task<Void, Never>?
    @State private var isVisible = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
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
                StickerShape(shape: RetroPanelShape(), fill: Kids.sun, strokeWidth: 1.25)
            )
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.10), radius: 3, x: 0, y: 2)
            .scaleEffect(reduceMotion || scenePhase != .active ? 1 : pop)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("\(count) coins. Opens the coin shop.")
        .onAppear { isVisible = true }
        .onChange(of: count) { _ in
            cancelPop()
            guard isVisible, !reduceMotion, scenePhase == .active else { return }
            withAnimation(.easeOut(duration: 0.1)) { pop = 1.06 }
            popTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 120_000_000) }
                catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.15)) { pop = 1 }
                popTask = nil
            }
        }
        .onChange(of: reduceMotion) { if $0 { cancelPop() } }
        .onChange(of: scenePhase) { if $0 != .active { cancelPop() } }
        .onDisappear { isVisible = false; cancelPop() }
        .transaction {
            if reduceMotion || scenePhase != .active { $0.animation = nil; $0.disablesAnimations = true }
        }
    }

    private func cancelPop() {
        popTask?.cancel()
        popTask = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { pop = 1 }
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
            RetroSymbol("🔥", size: isIPad ? 22 : 16)
            Text("\(days) DAY STREAK!")
                .font(Kids.nunito(isIPad ? 16 : 12, weight: .heavy))
                .tracking(1)
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, isIPad ? 20 : 14).padding(.vertical, isIPad ? 11 : 8)
        .background(
            StickerShape(shape: RetroPanelShape(), fill: Kids.peach, strokeWidth: 1.25)
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.10), radius: 3, x: 0, y: 2)
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

    @State private var pieces: [Piece] = {
        let colors: [Color] = [
            Theme.gold, Theme.orange, Theme.purple, Theme.cyan, Theme.teal, Theme.red, .white,
            Kids.peach, Kids.grass, Kids.sky
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
    @State private var didConsumeCelebration = false
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var canAnimate: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        Group {
            if canAnimate && !finished {
                GeometryReader { geo in
                    ForEach(pieces) { piece in
                        RetroPanelShape(cornerRadius: 2)
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
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: canAnimate) {
            guard !didConsumeCelebration else { return }
            didConsumeCelebration = true
            guard canAnimate else { finishCelebration(); return }
            // Render the starting positions, then run this presentation once.
            do { try await Task.sleep(nanoseconds: 50_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            isAnimating = true
            do { try await Task.sleep(nanoseconds: 5_000_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            finishCelebration()
        }
        .onChange(of: canAnimate) { if !$0 { finishCelebration() } }
        .onDisappear { finishCelebration() }
    }

    private func finishCelebration() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            didConsumeCelebration = true
            finished = true
        }
    }
}

/// A lightweight, intentional placeholder while a custom name is being typed.
struct RetroCustomCreaturePreview: View {
    var size: CGFloat = 50
    var body: some View {
        ZStack {
            RetroPanelShape().fill(Kids.panel)
            RetroPanelShape().strokeBorder(Kids.outline, lineWidth: 1.25)
            Image(systemName: "pencil.and.outline")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundColor(Kids.grassDeep)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Custom creature preview")
    }
}

/// Small, deterministic arena scene; keeps the selector in the game's pixel language.
struct RetroArenaThumbnail: View {
    let environment: BattleEnvironment
    var body: some View {
        Canvas { context, size in
            let unit = size.width / 32
            func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                context.fill(Path(CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)), with: .color(color))
            }
            let isDark = environment == .night || environment == .storm || environment == .volcano
            block(0, 0, 32, 20, isDark ? Kids.console : Kids.sky)
            block(0, 14, 32, 6, environment == .ocean ? Kids.skyDeep : environment == .arctic ? Kids.cream : environment == .desert ? Kids.peach : Kids.grassDeep)
            switch environment {
            case .ocean:
                for x in stride(from: CGFloat(0), to: 32, by: 9) {
                    block(x, 12, 6, 2, Kids.skyDeep)
                    block(x + 1, 16, 4, 1, Kids.sky)
                }
            case .sky:
                block(3, 5, 10, 3, Kids.cream); block(5, 3, 5, 2, Kids.cream)
                block(21, 9, 9, 3, Kids.cream); block(23, 7, 4, 2, Kids.cream)
                block(0, 14, 32, 6, Kids.sky)
            case .arctic:
                block(6, 10, 11, 4, Kids.cream); block(8, 7, 7, 3, Kids.cream)
                block(10, 4, 3, 3, Kids.cream); block(20, 11, 8, 3, Kids.panel)
            case .desert:
                block(6, 7, 2, 8, Kids.grassDeep); block(3, 9, 3, 2, Kids.grassDeep)
                block(9, 6, 2, 6, Kids.grassDeep); block(8, 10, 3, 2, Kids.grassDeep)
                block(23, 3, 5, 5, Kids.sun)
            case .jungle:
                for x in stride(from: CGFloat(2), to: 32, by: 10) {
                    block(x + 3, 5, 2, 10, Kids.peachDeep)
                    block(x, 3, 8, 5, Kids.grassDeep); block(x + 1, 1, 6, 3, Kids.grassDeep)
                }
            case .volcano:
                block(8, 10, 17, 5, Kids.ink); block(11, 7, 11, 3, Kids.ink)
                block(14, 4, 5, 3, Kids.pinkDeep); block(16, 6, 2, 8, Kids.peach)
                block(0, 17, 32, 3, Kids.pinkDeep)
            case .night:
                block(24, 3, 5, 5, Kids.sun); block(26, 2, 4, 4, Kids.console)
                block(4, 4, 1, 1, Kids.cream); block(12, 7, 1, 1, Kids.cream); block(18, 3, 1, 1, Kids.cream)
            case .storm:
                block(5, 3, 21, 4, Kids.ink); block(9, 1, 11, 2, Kids.ink)
                block(16, 7, 3, 3, Kids.sun); block(14, 10, 4, 2, Kids.sun); block(15, 12, 2, 3, Kids.sun)
            case .grassland:
                block(24, 3, 4, 4, Kids.sun)
                block(3, 11, 9, 3, Kids.grass); block(6, 9, 5, 2, Kids.grass)
                block(20, 12, 10, 2, Kids.grass)
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .clipShape(RetroPanelShape())
        .accessibilityHidden(true)
    }
}

#if DEBUG
/// Visual QA uses the production views with isolated, deterministic local state.
/// This host is compiled out of Release and accepts only the Testing bundle.
@MainActor
struct RetroUIFixtureHost: View {
    let screen: String
    @Environment(\.dynamicTypeSize) private var fixtureTextSize
    @State private var arena: BattleEnvironment = .grassland
    @State private var effects = true
    @State private var presented = true
    @State private var exportImage: UIImage?

    static func supports(_ screen: String) -> Bool {
        ["ui-home-navigation", "ui-picker", "ui-arena", "ui-book", "ui-facts", "ui-settings", "ui-shop", "ui-coins",
         "ui-parent", "ui-pin", "ui-grownups", "ui-help", "ui-tournament", "ui-bracket",
         "ui-wager", "ui-champion", "ui-share-duel", "ui-share-team", "ui-share-tournament", "ui-share-custom",
         "ui-reading-solo", "ui-reading-team", "ui-reading-tournament", "ui-reading-facts"].contains(screen)
    }

    init(screen: String) {
        self.screen = screen
    }

    /// Call once during isolated test app startup, before SwiftUI evaluates body.
    static func prepare(screen: String) {
        guard AppConfig.isUITesting, AppConfig.isIsolatedTestBuild else { return }
        if screen == "ui-home-navigation" {
            UserSettings.shared.tournamentUnlocked = true
            TournamentManager.shared.clear()
        }
        for animal in [Animals.lion, Animals.gorilla, Animals.tiger, Animals.wolf, Animals.elephant,
                       Animals.great_white_shark, Animals.bald_eagle, Animals.t_rex] {
            StickerCollection.shared.collect(animal)
        }
        if screen == "ui-wager" || screen == "ui-champion" {
            TournamentManager.shared.activeTournament = Self.tournament(completed: screen == "ui-champion")
        }
    }

    var body: some View {
        Group {
            if AppConfig.isUITesting && AppConfig.isIsolatedTestBuild {
                fixtureContent
            } else {
                KidsHomeView()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fixture.screen.\(screen)")
        .overlay(alignment: .bottomTrailing) {
            if screen.hasPrefix("ui-reading-") || ProcessInfo.processInfo.environment["AVA_READING_AX3"] == "1" {
                Text("TEXT: \(String(describing: fixtureTextSize))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white).padding(3).background(.black)
                    .accessibilityIdentifier("fixture.reading.contentSize")
                    .accessibilityValue(String(describing: fixtureTextSize))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var fixtureContent: some View {
        switch screen {
        case "ui-home-navigation": KidsHomeView()
        case "ui-picker": NavigationStack { KidsAnimalPickerView() }
        case "ui-arena":
            KidsPreBattleView(fighter1: Animals.lion, fighter2: Animals.great_white_shark,
                              selectedEnvironment: $arena, arenaEffectsEnabled: $effects,
                              isPresented: $presented, onStart: {})
        case "ui-book": KidsStickerBookView()
        case "ui-facts": AnimalFactsSheet(animal: Animals.lion)
        case "ui-reading-facts": AnimalFactsSheet(animal: Animals.peregrine_falcon)
        case "ui-reading-solo":
            KidsBattleView(fighter1: Animals.lion, fighter2: Animals.gorilla,
                           environment: .grassland, arenaEffectsEnabled: true)
        case "ui-reading-team":
            MeleeBattleView(teamA: [Animals.lion, Animals.gorilla, Animals.tiger, Animals.wolf],
                            teamB: [Animals.elephant, Animals.great_white_shark, Animals.bald_eagle, Animals.t_rex])
        case "ui-reading-tournament":
            KidsTournamentBattleView(fighter1: Animals.lion, fighter2: Animals.gorilla,
                                     environment: .grassland, arenaEffectsEnabled: true,
                                     quickMode: false, tournamentContext: "Quarter-final (round 1 of 3, match 2/4).",
                                     onComplete: { _ in })
        case "ui-settings": KidsSettingsView()
        case "ui-shop": KidsShopView()
        case "ui-coins": KidsCoinShopSheet(isPresented: $presented)
        case "ui-parent": ParentGateSheet(isPresented: $presented, onSuccess: {})
        case "ui-pin": ParentalPINSheet(mode: .setup, onSuccess: {}, onCancel: {})
        case "ui-grownups": GrownUpZoneView()
        case "ui-help": HowToPlayView()
        case "ui-tournament": NavigationStack { TournamentSetupView(onContinue: { _, _ in }) }
        case "ui-bracket":
            NavigationStack {
                BracketPreviewView(tournament: Self.tournament(), onConfirm: {}, onReroll: {}, onForfeit: {})
            }
        case "ui-wager":
            NavigationStack { RoundWagerView(tournament: Self.tournament(), roundIndex: 0, onDone: {}) }
        case "ui-champion":
            TournamentCompleteView(tournament: Self.tournament(completed: true), onPlayAgain: {}, onExit: {})
        case "ui-share-duel", "ui-share-team", "ui-share-tournament", "ui-share-custom":
            ZStack {
                Kids.cream.ignoresSafeArea()
                if let exportImage {
                    ScrollView {
                        Image(uiImage: exportImage).resizable().interpolation(.none).scaledToFit()
                            .accessibilityLabel("Rendered retro share card")
                            .accessibilityIdentifier("fixture.export.ready")
                    }
                } else {
                    ProgressView("Rendering share card")
                }
            }
            .task { await renderExport() }
        default: KidsHomeView()
        }
    }

    private static func result(_ winner: Animal) -> BattleResult {
        BattleResult(winner: winner.id,
                     narration: "The lion held its ground while the gorilla made one final charge. A quick sidestep and a powerful roar gave the lion the edge in this close match.",
                     funFact: "A lion's roar can be heard up to five miles away.",
                     winnerHealthPercent: 64, loserHealthPercent: 12,
                     why: "Strong paws and quick footwork helped the lion hold its ground.")
    }

    private static func tournament(completed: Bool = false) -> Tournament {
        let pool = Array(Animals.all.prefix(16))
        var round = stride(from: 0, to: pool.count, by: 2).map { index in
            Matchup(id: UUID(), fighter1: pool[index], fighter2: pool[index + 1], environment: .grassland,
                    wager: nil, result: completed ? result(pool[index]) : nil)
        }
        var rounds = [round]
        if completed {
            while round.count > 1 {
                let winners = round.compactMap(\.winningFighter)
                round = stride(from: 0, to: winners.count, by: 2).map { index in
                    Matchup(id: UUID(), fighter1: winners[index], fighter2: winners[index + 1],
                            environment: .grassland, wager: nil, result: result(winners[index]))
                }
                rounds.append(round)
            }
        } else {
            rounds += [[], [], []]
        }
        return Tournament(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), size: .sixteen,
                          selectionMode: .manual, phase: completed ? .complete : .roundWager(roundIndex: 0),
                          bracket: Bracket(rounds: rounds), grandChampion: nil, rerollUsed: false,
                          ledger: [], schemaVersion: Tournament.currentSchemaVersion,
                          resolvedRounds: completed ? Set(0..<4) : [], grandChampionResolved: completed)
    }

    private func renderExport() async {
        let image: UIImage?
        switch screen {
        case "ui-share-custom":
            let lion = Animal(id: "custom_fixture_blue_lion", name: "Blue Lion", emoji: "", category: .land,
                              pixelColor: "#5997B8", size: 3, isCustom: true)
            let fantasy = Animal(id: "custom_fixture_glimmerflux", name: "Glimmerflux", emoji: "", category: .fantasy,
                                 pixelColor: "#9D83C5", size: 3, isCustom: true)
            let result = BattleResult(winner: lion.id,
                                      narration: "Blue Lion stood firm as Glimmerflux bounded across the arena. A quick sidestep gave Blue Lion the edge.",
                                      funFact: "A lion's roar can be heard up to five miles away.",
                                      winnerHealthPercent: 64, loserHealthPercent: 12)
            image = await KidsShareCard.renderWithCachedImages(fighter1: lion, fighter2: fantasy, result: result)
        case "ui-share-team":
            let teamA = [Animals.lion, Animals.gorilla, Animals.tiger, Animals.wolf]
            let teamB = [Animals.elephant, Animals.great_white_shark, Animals.bald_eagle, Animals.t_rex]
            let result = MeleeResult(winningTeam: .A, narration: Self.result(Animals.lion).narration,
                                    funFact: Self.result(Animals.lion).funFact, mvp: Animals.lion.id,
                                    teamAHealth: 64, teamBHealth: 12)
            image = await MeleeShareCard.renderWithCachedImages(teamA: teamA, teamB: teamB, result: result)
        case "ui-share-tournament":
            image = await TournamentShareCard.renderWithCachedImages(tournament: Self.tournament(completed: true),
                                                                      grandChampionPayout: 100, netCoinDelta: 150)
        default:
            image = await KidsShareCard.renderWithCachedImages(fighter1: Animals.lion, fighter2: Animals.gorilla,
                                                               result: Self.result(Animals.lion), environment: .jungle,
                                                               arenaEffectsEnabled: true)
        }
        exportImage = image
        if let data = image?.pngData() {
            // QA runner can copy the full-size rendered artifact from the isolated app container.
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(screen).png")
            try? data.write(to: url, options: .atomic)
        }
    }
}
#endif
