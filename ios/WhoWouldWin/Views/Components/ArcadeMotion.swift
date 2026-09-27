import SwiftUI

/// Ambient motion is opt-in. A screen supplies its visible viewport and whether
/// a sheet/navigation destination is covering it; exported cards remain static.
private struct ArcadeViewportKey: EnvironmentKey {
    static let defaultValue = CGRect.zero
}
private struct ArcadeMotionEnabledKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var arcadeViewport: CGRect {
        get { self[ArcadeViewportKey.self] }
        set { self[ArcadeViewportKey.self] = newValue }
    }
    var arcadeMotionEnabled: Bool {
        get { self[ArcadeMotionEnabledKey.self] }
        set { self[ArcadeMotionEnabledKey.self] = newValue }
    }
}
private struct ArcadeViewport: ViewModifier {
    let active: Bool
    @State private var bounds = CGRect.zero

    func body(content: Content) -> some View {
        content
            .environment(\.arcadeViewport, bounds)
            .environment(\.arcadeMotionEnabled, active)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bounds = $0 }
    }
}
extension View {
    func arcadeMotionViewport(active: Bool = true) -> some View {
        modifier(ArcadeViewport(active: active))
    }
}

/// Bounds are measured outside the animated artwork, so the motion itself cannot
/// repeatedly change visibility. More than half must be inside the scroll viewport.
enum ArcadeMotionVisibility {
    static func canAnimate(enabled: Bool, reduceMotion: Bool, sceneActive: Bool,
                           appeared: Bool, bounds: CGRect, viewport: CGRect) -> Bool {
        guard enabled, !reduceMotion, sceneActive, appeared,
              !bounds.isNull, !bounds.isInfinite, !viewport.isNull, !viewport.isInfinite,
              [bounds.minX, bounds.minY, bounds.width, bounds.height,
               viewport.minX, viewport.minY, viewport.width, viewport.height].allSatisfy({ $0.isFinite }),
              bounds.size.width > 0, bounds.size.height > 0,
              viewport.size.width > 0, viewport.size.height > 0 else { return false }
        let visible = bounds.intersection(viewport)
        return !visible.isNull && visible.width * visible.height > bounds.width * bounds.height * 0.5
    }
}

/// One low-frequency clock per featured element, paused for hidden pages, scroll
/// positions, covered screens, inactive scenes and accessibility preferences.
struct ArcadeMotionClock<Content: View>: View {
    var enabled = true
    var traceName = "logo"
    @ViewBuilder let content: (TimeInterval) -> Content
    @Environment(\.arcadeViewport) private var viewport
    @Environment(\.arcadeMotionEnabled) private var screenEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var appeared = false
    @State private var bounds = CGRect.zero
    @State private var started = Date()
    @State private var traceID = UUID()

    private var running: Bool {
        ArcadeMotionVisibility.canAnimate(enabled: enabled && screenEnabled,
            reduceMotion: reduceMotion, sceneActive: scenePhase == .active,
            appeared: appeared, bounds: bounds, viewport: viewport)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !running)) { timeline in
            content(running ? max(0, timeline.date.timeIntervalSince(started)) : 0)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { bounds = $0 }
        .onAppear { started = Date(); appeared = true }
        .onDisappear { appeared = false }
        .onChange(of: running) { active in
            if active { started = Date() }
        }
        #if DEBUG
        .onChange(of: diagnosticState) { trace($0) }
        #endif
    }

    #if DEBUG
    private var diagnosticState: [String] {
        [running.description, enabled.description, screenEnabled.description,
         reduceMotion.description, (scenePhase == .active).description, appeared.description,
         NSCoder.string(for: bounds), NSCoder.string(for: viewport)]
    }

    /// Explicit isolated-fixture diagnostics for temporal QA, compiled out of Release.
    /// Never enabled for the owner's real library or ordinary Debug sessions.
    private func trace(_ state: [String]) {
        guard AppConfig.isUITesting, AppConfig.isIsolatedTestBuild,
              ProcessInfo.processInfo.environment["AVA_MOTION_TRACE"] == "1" else { return }
        let fields = ["running", "elementEnabled", "screenEnabled", "reduceMotion", "sceneActive", "appeared", "bounds", "viewport"]
        var record = Dictionary(uniqueKeysWithValues: zip(fields, state))
        record["name"] = traceName
        record["id"] = traceID.uuidString
        record["screen"] = AppConfig.fixtureScreen ?? "home"
        record["time"] = ISO8601DateFormatter().string(from: Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arcade-motion.jsonl")
        guard var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
        data.append(0x0A)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        do { try handle.seekToEnd(); try handle.write(contentsOf: data) } catch { }
    }
    #endif
}

enum ArcadeCreatureMood { case idle, winner }

/// Long resting intervals keep the page calm. Values are absolute samples rather
/// than accumulating springs/timers, so a return from background never catches up.
struct ArcadeCreatureFrame: Equatable {
    var lift: CGFloat = 0
    var lean: Double = 0
    var heightScale: CGFloat = 1
    var sparkle: Double = 0
    static let resting = ArcadeCreatureFrame()

    static func sample(time: TimeInterval, mood: ArcadeCreatureMood, delay: Double = 0) -> Self {
        guard time.isFinite, delay.isFinite, time > max(0, delay) else { return .resting }
        let cycle = (time - max(0, delay)).truncatingRemainder(dividingBy: 8)
        var frame = Self.resting
        // A small, grounded breath/pose, followed by five seconds of stillness.
        if cycle >= 1.4 && cycle < 3.4 {
            let progress = (cycle - 1.4) / 2
            let breath = sin(progress * .pi)
            frame.heightScale = 1 + breath * (mood == .winner ? 0.018 : 0.012)
            if mood == .winner {
                frame.lift = -CGFloat(breath) * 2
                frame.lean = sin(progress * 2 * .pi) * 1.2
            }
        }
        // A single pixel glint, separated from the pose and its entrance reveal.
        if mood == .winner && cycle >= 4.6 && cycle < 5.4 {
            frame.sparkle = pow(sin((cycle - 4.6) / 0.8 * .pi), 2) * 0.85
        }
        return frame
    }
}

struct LivingCreatureArtwork: View {
    let animal: Animal
    let size: CGFloat
    var mood: ArcadeCreatureMood = .idle
    var enabled = true
    var delay: Double = 0

    var body: some View {
        ArcadeMotionClock(enabled: enabled, traceName: "\(mood)-\(animal.id)") { time in
            let frame = ArcadeCreatureFrame.sample(time: time, mood: mood, delay: delay)
            RetroCreatureArtwork(animal: animal, size: size)
                .scaleEffect(x: 1, y: frame.heightScale, anchor: .bottom)
                .rotationEffect(.degrees(frame.lean), anchor: .bottom)
                .offset(y: frame.lift)
                .overlay(alignment: .topTrailing) {
                    PixelGlint()
                        .fill(Kids.sun)
                        .frame(width: 14, height: 14)
                        .opacity(frame.sparkle)
                        .padding(.trailing, 3).padding(.top, 8)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
        }
    }

    private struct PixelGlint: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let unit = rect.width / 7
            path.addRect(CGRect(x: unit * 3, y: 0, width: unit, height: rect.height))
            path.addRect(CGRect(x: 0, y: unit * 3, width: rect.width, height: unit))
            path.addRect(CGRect(x: unit * 2, y: unit * 2, width: unit * 3, height: unit * 3))
            return path
        }
    }
}
