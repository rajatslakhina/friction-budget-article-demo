/// A user goal written as something a coding agent can be measured against.
///
/// "Make it intuitive" is not checkable. "Find the dark-mode setting in three inputs or fewer,
/// and every image you insert can be dragged afterwards" is.
public struct Journey: Identifiable, Equatable, Sendable {
    public var id: String
    public var goal: String
    public var budget: Budget
    /// Some questions stay with a person ("is this pleasant?"). A journey marked this way can never pass on its own.
    public var needsHumanReview: Bool

    public init(id: String, goal: String, budget: Budget, needsHumanReview: Bool = false) {
        self.id = id
        self.goal = goal
        self.budget = budget
        self.needsHumanReview = needsHumanReview
    }
}

/// The friction a journey is allowed to cost. A `nil` limit is not checked.
public struct Budget: Equatable, Sendable {
    public var maxInputs: Int?
    public var maxSecondsToFirstResult: Double?
    /// Every object the user creates must be reachable again (select, move, delete).
    public var everyCreationReachable: Bool
    /// Backing out must leave the document exactly as it was.
    public var cancelLeavesNoTrace: Bool
    /// Every destructive action must offer a one-step undo.
    public var destructiveNeedsUndo: Bool
    /// Controls that must be hittable in the journey's environment.
    public var requiredControls: [String]

    public init(maxInputs: Int? = nil,
                maxSecondsToFirstResult: Double? = nil,
                everyCreationReachable: Bool = false,
                cancelLeavesNoTrace: Bool = false,
                destructiveNeedsUndo: Bool = false,
                requiredControls: [String] = []) {
        self.maxInputs = maxInputs.map { max(0, $0) }
        self.maxSecondsToFirstResult = maxSecondsToFirstResult.map { max(0, $0) }
        self.everyCreationReachable = everyCreationReachable
        self.cancelLeavesNoTrace = cancelLeavesNoTrace
        self.destructiveNeedsUndo = destructiveNeedsUndo
        self.requiredControls = requiredControls
    }
}
