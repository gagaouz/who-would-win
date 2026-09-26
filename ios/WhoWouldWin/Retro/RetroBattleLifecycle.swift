import Foundation

/// Shared by the solo and team models. A presentation can accept one result and
/// finish once; late network answers and callbacks from a rematch are ignored.
struct RetroBattleLifecycle<Result: Equatable> {
    private(set) var id = UUID()
    private(set) var result: Result?
    private(set) var started = false
    private(set) var completed = false
    private(set) var cancelled = false

    mutating func begin() -> UUID? {
        guard !started, !cancelled else { return nil }
        started = true
        return id
    }

    @discardableResult
    mutating func accept(_ value: Result, for session: UUID) -> Bool {
        guard session == id, started, !cancelled, result == nil else { return false }
        result = value
        return true
    }

    @discardableResult
    mutating func finish(_ session: UUID) -> Bool {
        guard session == id, !cancelled, !completed, result != nil else { return false }
        completed = true
        return true
    }

    mutating func cancel() { cancelled = true }
    mutating func reset() { self = Self() }
}

/// There are deliberately no damage or HP fields in this presentation contract.
/// The scene illustrates the accepted answer; it never resolves a battle.
enum RetroBattleOutcome: Equatable {
    case draw
    case victory(side: Int, mvpID: String)

    static func solo(_ result: BattleResult?, first: Animal, second: Animal) -> Self? {
        guard let result else { return nil }
        if result.winner == "draw" { return .draw }
        if result.winner == first.id { return .victory(side: 0, mvpID: first.id) }
        if result.winner == second.id { return .victory(side: 1, mvpID: second.id) }
        return nil
    }

    static func team(_ result: MeleeResult?) -> Self? {
        guard let result else { return nil }
        return .victory(side: result.winningTeam == .A ? 0 : 1, mvpID: result.mvp)
    }

    var winningSide: Int? {
        if case .victory(let side, _) = self { return side }
        return nil
    }
}

/// Scene-relative time pauses with the app, so returning from an interruption
/// cannot jump through every impact or repeat a completion callback.
struct RetroPresentationClock {
    private(set) var elapsed: TimeInterval = 0
    private var lastTime: TimeInterval?

    mutating func tick(_ now: TimeInterval, active: Bool) -> TimeInterval {
        defer { lastTime = active ? now : nil }
        guard active, let lastTime else { return elapsed }
        elapsed += max(0, min(0.1, now - lastTime))
        return elapsed
    }

    mutating func pause() { lastTime = nil }
    mutating func reset() { self = Self() }
}

/// Guards view re-entry within a process in addition to the result view's local
/// state. New rematches have new IDs; scene replay has the same ID.
@MainActor
enum RetroBattleSettlement {
    private static var settled: [UUID] = []
    static func claim(_ id: UUID) -> Bool {
        guard !settled.contains(id) else { return false }
        settled.append(id)
        if settled.count > 512 { settled.removeFirst(settled.count - 512) }
        return true
    }
}
