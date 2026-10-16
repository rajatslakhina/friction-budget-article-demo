/// One way a trace went over its journey's budget.
public enum Violation: Equatable, Hashable, Sendable, CustomStringConvertible {
    case tooManyInputs(used: Int, limit: Int)
    case slowFirstResult(seconds: Double, limit: Double)
    case noResult
    case stuckCreation(String)
    case irreversible(String)
    case cancelLeftResidue
    /// The budget asks for a clean cancel, but the trace has no before/after digests to prove it.
    case cancelUnverified
    case notHittable(String)
    /// The trace was recorded for a different journey.
    case wrongJourney(expected: String, got: String)

    public var description: String {
        switch self {
        case let .tooManyInputs(used, limit): return "\(used) inputs, budget \(limit)"
        case let .slowFirstResult(seconds, limit): return "first result at \(Self.format(seconds)) s, budget \(Self.format(limit)) s"
        case .noResult: return "no result ever appeared"
        case let .stuckCreation(id): return "\(id) can't be selected or moved after it's placed"
        case let .irreversible(id): return "\(id) has no undo"
        case .cancelLeftResidue: return "Cancel left the document changed"
        case .cancelUnverified: return "Cancel path not verified (no before/after state)"
        case let .notHittable(control): return "\(control) is not hittable"
        case let .wrongJourney(expected, got): return "trace is for \(got), not \(expected)"
        }
    }

    /// The bucket a violation belongs to, used for summaries.
    public var kind: String {
        switch self {
        case .tooManyInputs: return "inputs"
        case .slowFirstResult, .noResult: return "latency"
        case .stuckCreation: return "reachability"
        case .irreversible: return "undo"
        case .cancelLeftResidue, .cancelUnverified: return "cancel"
        case .notHittable: return "layout"
        case .wrongJourney: return "trace"
        }
    }

    static func format(_ value: Double) -> String {
        let tenths = Int((value * 10).rounded())
        return "\(tenths / 10).\(abs(tenths % 10))"
    }
}

public enum FrictionCheck {
    /// Every budget line the trace breaks, in budget order. Empty means within budget.
    public static func violations(of journey: Journey, in trace: Trace) -> [Violation] {
        guard trace.journeyID == journey.id else {
            return [.wrongJourney(expected: journey.id, got: trace.journeyID)]
        }
        let metrics = TraceMetrics(trace)
        let budget = journey.budget
        var found: [Violation] = []

        if let limit = budget.maxInputs, metrics.inputs > limit {
            found.append(.tooManyInputs(used: metrics.inputs, limit: limit))
        }
        if let limit = budget.maxSecondsToFirstResult {
            if let seconds = metrics.secondsToFirstResult {
                if seconds > limit { found.append(.slowFirstResult(seconds: seconds, limit: limit)) }
            } else {
                found.append(.noResult)
            }
        }
        if budget.everyCreationReachable {
            found += metrics.stuckCreations.map(Violation.stuckCreation)
        }
        if budget.destructiveNeedsUndo {
            found += metrics.irreversible.map(Violation.irreversible)
        }
        if budget.cancelLeavesNoTrace {
            let digests = trace.events.filter { if case .stateDigest = $0 { return true } else { return false } }
            let cancelled = trace.events.contains(.cancel)
            if !cancelled || digests.count < 2 {
                found.append(.cancelUnverified)
            } else if metrics.cancelLeftResidue {
                found.append(.cancelLeftResidue)
            }
        }
        for control in budget.requiredControls where metrics.notHittable.contains(control) {
            found.append(.notHittable(control))
        }
        return found
    }
}
