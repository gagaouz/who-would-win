import SwiftUI

enum LeoTributeKind: Equatable { case happy, goodnight }

/// Ephemeral, result-local state. A burst of taps can replace one clip, never
/// queue several clips or restart the first celebration indefinitely.
struct LeoTributePlayback: Equatable {
    private(set) var tapCount = 0
    private(set) var generation = 0
    private(set) var animation: LeoTributeKind?

    static func isLeonidas(_ animal: Animal) -> Bool {
        animal.id == "great_dane" && !animal.isCustom
    }

    var message: String? {
        switch tapCount {
        case 0: return nil
        case 1, 2: return "Good boy, Leo!"
        default: return "Goodnight, handsome."
        }
    }

    var settledFrame: LeoTributeFrame {
        LeoTributeFrame(pose: tapCount == 1 || tapCount == 2 ? .reaction : .idle)
    }

    mutating func tap(reduceMotion: Bool) {
        guard tapCount < 3 else { return }
        tapCount += 1
        guard !reduceMotion else { stop(); return }
        if tapCount == 3 {
            generation += 1
            animation = .goodnight
        } else if animation == nil {
            generation += 1
            animation = .happy
        }
    }

    mutating func stop() {
        guard animation != nil else { return }
        generation += 1
        animation = nil
    }

    @discardableResult
    mutating func finish(generation expected: Int) -> Bool {
        guard generation == expected, animation != nil else { return false }
        animation = nil
        return true
    }
}

/// Absolute samples keep the finite animation deterministic after cancellation.
/// The character is always opaque and keeps its authored anatomy and proportions.
struct LeoTributeFrame: Equatable {
    var pose: RetroPose = .idle
    var liftFraction: CGFloat = 0
    var leanDegrees: Double = 0
    var heartOpacity: Double = 0
    var heartRiseFraction: CGFloat = 0
    static let duration: TimeInterval = 1.8

    static func sample(time: TimeInterval, kind: LeoTributeKind) -> Self {
        let settled = Self(pose: kind == .happy ? .reaction : .idle)
        guard time.isFinite, time >= 0, time < duration else { return settled }
        var frame = settled
        switch kind {
        case .happy:
            if time < 0.32 {
                frame.pose = .anticipation
            } else if time < 0.96 {
                frame.pose = .attack
                frame.liftFraction = -CGFloat(sin((time - 0.32) / 0.64 * .pi)) * 0.08
            } else {
                frame.pose = .reaction
                frame.leanDegrees = sin((time - 0.96) / 0.84 * 2 * .pi) * 3
            }
            let progress = min(1, max(0, (time - 0.24) / 1.56))
            frame.heartOpacity = sin(progress * .pi) * 0.9
            frame.heartRiseFraction = CGFloat(progress) * 0.14
        case .goodnight:
            // An affectionate head-up moment, then a quiet, present resting pose.
            if time < 1.2 {
                frame.pose = .reaction
                frame.leanDegrees = sin(time / 1.2 * .pi) * 2
            }
        }
        return frame
    }
}

struct LeoTributeBubblePlacement: Equatable {
    let width: CGFloat
    let offsetX: CGFloat

    static func make(bounds: CGRect, viewport: CGRect) -> Self? {
        guard !bounds.isNull, !bounds.isInfinite, !viewport.isNull, !viewport.isInfinite,
              [bounds.minX, bounds.minY, bounds.width, bounds.height,
               viewport.minX, viewport.minY, viewport.width, viewport.height].allSatisfy({ $0.isFinite }),
              bounds.width > 0, bounds.height > 0, viewport.width > 32, viewport.height > 0 else { return nil }
        let width = min(220, viewport.width - 32)
        let center = min(viewport.maxX - 16 - width / 2,
                         max(viewport.minX + 16 + width / 2, bounds.midX))
        return Self(width: width, offsetX: center - bounds.midX)
    }
}

/// Mount only for a winner and give this view the result's stable identity.
/// Nothing is stored beyond that result, and exports use ordinary static art.
struct LeoVictoryTribute: View {
    let animal: Animal
    let size: CGFloat
    let ringColor: Color

    @ObservedObject private var art = RetroAssetStore.shared
    @Environment(\.arcadeViewport) private var viewport
    @Environment(\.arcadeMotionEnabled) private var screenEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    @State private var bounds = CGRect.zero
    @State private var playback = LeoTributePlayback()
    @State private var sampledFrame = LeoTributeFrame()

    private struct Request: Equatable {
        let generation: Int
        let kind: LeoTributeKind
    }

    private var eligible: Bool { LeoTributePlayback.isLeonidas(animal) }
    private var active: Bool {
        ArcadeMotionVisibility.canAnimate(enabled: eligible && screenEnabled,
            reduceMotion: false, sceneActive: scenePhase == .active,
            appeared: appeared, bounds: bounds, viewport: viewport)
    }
    private var request: Request? {
        guard active, !reduceMotion, let kind = playback.animation else { return nil }
        return Request(generation: playback.generation, kind: kind)
    }
    private var frame: LeoTributeFrame {
        request == nil ? playback.settledFrame : sampledFrame
    }

    var body: some View {
        Group {
            if eligible {
                VStack(spacing: 8) {
                    reservedSpeech
                    Button(action: celebrate) { portrait }
                        .buttonStyle(.plain)
                        .disabled(!active)
                        .accessibilityLabel("Celebrate with Leonidas")
                        .accessibilityValue(playback.message ?? "Great Dane victory")
                        .accessibilityIdentifier("leo.tribute.button")
                        // Visibility follows the stationary button, not its speech
                        // slot or moving art; even a small roster portrait counts.
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bounds = $0 }
                }
                .frame(width: size)
            } else {
                portrait.accessibilityLabel(animal.name)
            }
        }
        .zIndex(playback.message == nil ? 0 : 1)
        .onAppear { appeared = true }
        .onDisappear { appeared = false; stop() }
        .onChange(of: active) { if !$0 { stop() } }
        .onChange(of: reduceMotion) { if $0 { stop() } }
        .task(id: request) {
            guard let request else { return }
            await play(request)
        }
        #if DEBUG
        .overlay(alignment: .bottomLeading) {
            if eligible, AppConfig.isUITesting, AppConfig.isIsolatedTestBuild {
                Text("LEO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white).background(Color.black)
                    .accessibilityIdentifier("leo.tribute.motion")
                    .accessibilityValue("reduced=\(reduceMotion);active=\(active);running=\(request != nil);taps=\(playback.tapCount);pose=\(frame.pose.rawValue)")
                    .allowsHitTesting(false)
            }
        }
        #endif
    }

    private var reservedSpeech: some View {
        let placement = LeoTributeBubblePlacement.make(bounds: bounds, viewport: viewport)
            ?? LeoTributeBubblePlacement(width: 220, offsetX: 0)
        return ZStack(alignment: .bottom) {
            // Reserve both phrases at their natural reading size before the
            // first tap. Message changes cannot move Leo or the neighboring row.
            speechBubble("Good boy, Leo!", placement: placement)
                .hidden().accessibilityHidden(true)
            speechBubble("Goodnight, handsome.", placement: placement)
                .hidden().accessibilityHidden(true)
            if active, let message = playback.message {
                speechBubble(message, placement: placement)
            }
        }
        .frame(width: size)
        .offset(x: placement.offsetX)
        .allowsHitTesting(false)
    }

    private var portrait: some View {
        Group {
            if eligible, let image = art.image(for: animal, pose: frame.pose) {
                let images = RetroPose.allCases.compactMap { art.image(for: animal, pose: $0) }
                let familyExtent = max(1, images.reduce(CGFloat.zero) { max($0, max($1.size.width, $1.size.height)) })
                let box = max(24, size - 22) * 0.88
                Image(uiImage: image).resizable().interpolation(.none)
                    .frame(width: image.size.width / familyExtent * box,
                           height: image.size.height / familyExtent * box)
                    .frame(width: box, height: box, alignment: .bottom)
                    .rotationEffect(.degrees(frame.leanDegrees), anchor: .bottom)
                    .offset(y: frame.liftFraction * min(size, 150))
                    .overlay(alignment: .top) { hearts }
                    .transaction { $0.animation = nil }
            } else {
                RetroCreatureArtwork(animal: animal, size: max(24, size - 22))
            }
        }
        .frame(width: size, height: size)
        .background(RetroPanelShape().fill(ringColor.opacity(0.24)))
        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
        .compositingGroup()
        .shadow(color: Kids.shadow.opacity(0.11), radius: 4, x: 0, y: 5)
        .contentShape(RetroPanelShape())
        .accessibilityHidden(true)
    }

    private var hearts: some View {
        HStack(spacing: max(10, size * 0.22)) {
            PixelHeart().fill(Kids.pinkDeep)
                .frame(width: max(7, min(11, size * 0.08)), height: max(6, min(10, size * 0.075)))
            PixelHeart().fill(Kids.pinkDeep)
                .frame(width: max(6, min(9, size * 0.065)), height: max(5, min(8, size * 0.06)))
                .offset(y: 5)
        }
        .offset(y: -frame.heartRiseFraction * min(size, 150))
        .opacity(frame.heartOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func speechBubble(_ message: String, placement: LeoTributeBubblePlacement) -> some View {
        VStack(spacing: 0) {
            Text(message)
                .readingText(.callout)
                .foregroundColor(Kids.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RetroPanelShape().fill(Kids.cream))
                .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                .accessibilityIdentifier("leo.tribute.message")
            BubbleTail().fill(Kids.outline)
                .frame(width: 12, height: 7)
                .overlay(alignment: .top) {
                    BubbleTail().fill(Kids.cream).frame(width: 9, height: 5)
                }
                .offset(x: max(-placement.width / 2 + 12,
                               min(placement.width / 2 - 12, -placement.offsetX)), y: -1)
                .accessibilityHidden(true)
        }
        .frame(width: placement.width)
        .fixedSize(horizontal: false, vertical: true)
        .shadow(color: Kids.shadow.opacity(0.12), radius: 3, x: 0, y: 3)
        .transaction { $0.animation = nil }
    }

    private func celebrate() {
        guard eligible, active else { return }
        let previousGeneration = playback.generation
        playback.tap(reduceMotion: reduceMotion)
        if let kind = playback.animation {
            // A repeated tap cannot rewind the current pose, including the ending.
            if playback.generation != previousGeneration {
                sampledFrame = .sample(time: 0, kind: kind)
            }
        } else {
            sampledFrame = playback.settledFrame
        }
    }

    private func stop() {
        playback.stop()
        sampledFrame = playback.settledFrame
    }

    @MainActor
    private func play(_ expected: Request) async {
        let started = ProcessInfo.processInfo.systemUptime
        while !Task.isCancelled {
            guard active, !reduceMotion, playback.generation == expected.generation,
                  playback.animation == expected.kind else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            if elapsed >= LeoTributeFrame.duration {
                if playback.finish(generation: expected.generation) {
                    sampledFrame = playback.settledFrame
                }
                return
            }
            sampledFrame = .sample(time: elapsed, kind: expected.kind)
            do { try await Task.sleep(nanoseconds: 33_333_333) }
            catch { return }
        }
    }

    private struct BubbleTail: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }

    private struct PixelHeart: Shape {
        func path(in rect: CGRect) -> Path {
            let rows = ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]
            var path = Path()
            for (y, row) in rows.enumerated() {
                for (x, bit) in row.enumerated() where bit == "1" {
                    path.addRect(CGRect(x: rect.minX + CGFloat(x) * rect.width / 7,
                                        y: rect.minY + CGFloat(y) * rect.height / 6,
                                        width: rect.width / 7, height: rect.height / 6))
                }
            }
            return path
        }
    }
}
