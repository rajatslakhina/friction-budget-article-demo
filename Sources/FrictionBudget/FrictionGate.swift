/// The release gate built on journeys: machine-checkable budgets first, a person last.
public struct FrictionGate: Sendable {
    public enum Verdict: Equatable, Sendable {
        case pass
        case fail([Violation])
        /// Within budget, but the journey is marked for a human ("is this pleasant?") and nobody has signed off yet.
        case awaitingHuman
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public var journey: Journey
        public var trace: Trace?
        public var screenshotPasses: Bool
        public var verdict: Verdict
        public var id: String { journey.id }
    }

    public enum Decision: Equatable, Sendable {
        case ship
        case blocked(failing: [String], awaitingHuman: [String], missingTraces: [String])
    }

    public var journeys: [Journey]
    /// Journey IDs a named person has signed off as pleasant to use.
    public var humanSignOffs: Set<String>

    public init(journeys: [Journey], humanSignOffs: Set<String> = []) {
        self.journeys = journeys
        self.humanSignOffs = humanSignOffs
    }

    public func rows(for traces: [Trace]) -> [Row] {
        journeys.map { journey in
            guard let trace = traces.first(where: { $0.journeyID == journey.id }) else {
                // A journey with no trace was never exercised. That is a failure, not a pass.
                return Row(journey: journey, trace: nil, screenshotPasses: false, verdict: .fail([.noResult]))
            }
            let violations = FrictionCheck.violations(of: journey, in: trace)
            let verdict: Verdict
            if !violations.isEmpty {
                verdict = .fail(violations)
            } else if journey.needsHumanReview && !humanSignOffs.contains(journey.id) {
                verdict = .awaitingHuman
            } else {
                verdict = .pass
            }
            return Row(journey: journey, trace: trace, screenshotPasses: ScreenshotOracle.passes(trace), verdict: verdict)
        }
    }

    public func decide(_ traces: [Trace]) -> Decision {
        let rows = rows(for: traces)
        let missing = rows.filter { $0.trace == nil }.map(\.id)
        let failing = rows.filter { row in
            if case .fail = row.verdict, row.trace != nil { return true } else { return false }
        }.map(\.id)
        let waiting = rows.filter { $0.verdict == .awaitingHuman }.map(\.id)
        if failing.isEmpty && waiting.isEmpty && missing.isEmpty { return .ship }
        return .blocked(failing: failing, awaitingHuman: waiting, missingTraces: missing)
    }
}

public struct GateSummary: Equatable, Sendable {
    public var screenshotGreen: Int
    public var passed: Int
    public var failed: Int
    public var awaitingHuman: Int
    public var total: Int
    /// Violation counts by kind, sorted by kind name.
    public var byKind: [(kind: String, count: Int)]

    public init(_ rows: [FrictionGate.Row]) {
        total = rows.count
        screenshotGreen = rows.filter(\.screenshotPasses).count
        var passed = 0, failed = 0, waiting = 0
        var kinds: [String: Int] = [:]
        for row in rows {
            switch row.verdict {
            case .pass: passed += 1
            case .awaitingHuman: waiting += 1
            case .fail(let violations):
                failed += 1
                for v in violations { kinds[v.kind, default: 0] += 1 }
            }
        }
        self.passed = passed
        self.failed = failed
        self.awaitingHuman = waiting
        self.byKind = kinds.sorted { $0.key < $1.key }.map { (kind: $0.key, count: $0.value) }
    }

    public static func == (lhs: GateSummary, rhs: GateSummary) -> Bool {
        lhs.screenshotGreen == rhs.screenshotGreen && lhs.passed == rhs.passed && lhs.failed == rhs.failed
            && lhs.awaitingHuman == rhs.awaitingHuman && lhs.total == rhs.total
            && lhs.byKind.map(\.kind) == rhs.byKind.map(\.kind) && lhs.byKind.map(\.count) == rhs.byKind.map(\.count)
    }
}
