import Foundation

/// Persists how many times SecretAgent may handle signing requests before stopping itself.
public enum AgentCallLimitSettings {

    public static let maxLimit = 100
    public static let unlimited = 0

    public struct State: Codable, Equatable, Sendable {
        public var limit: Int
        public var remaining: Int?

        public init(limit: Int = 0, remaining: Int? = nil) {
            self.limit = limit
            self.remaining = remaining
        }
    }

    private static let fileName = "agent-call-limit.json"
    private static let lock = NSLock()

    public static var fileURL: URL {
        URL.agentHomeURL.appendingPathComponent(fileName)
    }

    public static func load() -> State {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked()
    }

    public static func setLimit(_ limit: Int) {
        lock.lock()
        defer { lock.unlock() }
        var state = loadUnlocked()
        state.limit = limit == unlimited ? unlimited : clamped(limit)
        if state.limit == unlimited {
            state.remaining = nil
        }
        saveUnlocked(state)
    }

    /// Resets the remaining count from the configured limit. Call immediately before launching SecretAgent.
    public static func resetForLaunch() {
        lock.lock()
        defer { lock.unlock() }
        var state = loadUnlocked()
        if state.limit > unlimited {
            state.remaining = state.limit
        } else {
            state.remaining = nil
        }
        saveUnlocked(state)
    }

    public static func clamped(_ value: Int) -> Int {
        min(max(value, 1), maxLimit)
    }

    public static func isExhausted(_ state: State = load()) -> Bool {
        state.limit > unlimited && state.remaining == 0
    }

    fileprivate static func persistRemaining(_ remaining: Int?, forLimit limit: Int) {
        lock.lock()
        defer { lock.unlock() }
        var state = loadUnlocked()
        state.limit = limit
        state.remaining = remaining
        saveUnlocked(state)
    }

    private static func loadUnlocked() -> State {
        let url = fileURL
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    private static func saveUnlocked(_ state: State) {
        let url = fileURL
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

}

/// In-process signing counter. Loaded once when SecretAgent starts; no per-request disk reads.
public final class AgentCallLimitTracker: @unchecked Sendable {

    private let lock = NSLock()
    private let limit: Int
    private var remaining: Int?

    public init(state: AgentCallLimitSettings.State = AgentCallLimitSettings.load()) {
        limit = state.limit
        if state.limit > AgentCallLimitSettings.unlimited {
            remaining = state.remaining ?? state.limit
        } else {
            remaining = nil
        }
    }

    /// Records one signing request. Returns `true` when the agent should stop.
    public func recordSignRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard limit > AgentCallLimitSettings.unlimited, var count = remaining else {
            return false
        }
        count -= 1
        remaining = count
        AgentCallLimitSettings.persistRemaining(count, forLimit: limit)
        return count <= 0
    }

}
