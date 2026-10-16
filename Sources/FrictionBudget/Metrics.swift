/// Numbers derived from a trace's events. Nothing here is self-reported by the build under test.
public struct TraceMetrics: Equatable, Sendable {
    public var inputs: Int
    /// `nil` when no result ever appeared.
    public var secondsToFirstResult: Double?
    /// Objects created and never successfully reached afterwards.
    public var stuckCreations: [String]
    /// Destructive actions with no undo offered.
    public var irreversible: [String]
    /// `true` when the user cancelled and the last digest differs from the first one.
    public var cancelLeftResidue: Bool
    public var notHittable: [String]

    public init(_ trace: Trace) {
        var inputs = 0
        var firstResult: Double?
        var created: [String] = []
        var reached: Set<String> = []
        var irreversible: [String] = []
        var digests: [String] = []
        var cancelled = false
        var notHittable: [String] = []

        for event in trace.events {
            switch event {
            case .input:
                inputs += 1
            case .firstResult(let seconds):
                // Keep the earliest one, in case a trace records several.
                if firstResult.map({ seconds < $0 }) ?? true { firstResult = max(0, seconds) }
            case .created(let id):
                if !created.contains(id) { created.append(id) }
            case .reach(let id, let succeeded):
                if succeeded { reached.insert(id) }
            case .destructive(let id, let undoable):
                if !undoable { irreversible.append(id) }
            case .stateDigest(let digest):
                digests.append(digest)
            case .cancel:
                cancelled = true
            case .notHittable(let control):
                if !notHittable.contains(control) { notHittable.append(control) }
            }
        }

        self.inputs = inputs
        self.secondsToFirstResult = firstResult
        self.stuckCreations = created.filter { !reached.contains($0) }
        self.irreversible = irreversible
        if cancelled, let first = digests.first, let last = digests.last, digests.count >= 2 {
            self.cancelLeftResidue = first != last
        } else {
            self.cancelLeftResidue = false
        }
        self.notHittable = notHittable
    }
}
