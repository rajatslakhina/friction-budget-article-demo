/// One thing that happened while a user (or a UI test acting as one) pursued a goal.
///
/// A trace is what an interaction-level test records: inputs, when the first useful
/// result appeared, what got created and whether it could be reached again, and
/// what state the document was in before and after. A static screenshot records none of this.
public enum Event: Equatable, Sendable {
    /// A user input: a tap, drag or typed entry. Each one counts against the input budget.
    case input(String)
    /// The first useful result became visible, in seconds since the journey started.
    case firstResult(seconds: Double)
    /// The user's action created an object (an image, a shape, a comment).
    case created(String)
    /// A later attempt to select, move or edit an object. `succeeded: false` means it was stuck.
    case reach(String, succeeded: Bool)
    /// A destructive action, and whether a one-step undo was offered right after it.
    case destructive(String, undoable: Bool)
    /// A digest of the document's state, recorded at the start and after the user backs out.
    case stateDigest(String)
    /// The user abandoned the task (Cancel, swipe down, Back).
    case cancel
    /// A control the journey needs was not hittable in this environment (clipped, covered, off-screen).
    case notHittable(String)
}

/// The conditions a journey ran under. Agents tend to check only the default one.
public struct Environment: Equatable, Hashable, Sendable, CustomStringConvertible {
    public enum Width: String, Sendable { case regular, compact }

    /// Content multiplier: 3 means three times the typical document size.
    public var contentScale: Int
    public var width: Width
    public var largeText: Bool

    public init(contentScale: Int = 1, width: Width = .regular, largeText: Bool = false) {
        self.contentScale = max(1, contentScale)
        self.width = width
        self.largeText = largeText
    }

    public static let `default` = Environment()

    public var isDefault: Bool { self == .default }

    public var description: String {
        var parts: [String] = []
        if contentScale > 1 { parts.append("\(contentScale)× content") }
        if width == .compact { parts.append("compact width") }
        if largeText { parts.append("large text") }
        return parts.isEmpty ? "default" : parts.joined(separator: ", ")
    }
}

/// A recorded run of one journey against one build.
public struct Trace: Equatable, Sendable {
    public var journeyID: String
    public var environment: Environment
    public var events: [Event]
    /// Whether the final screen shows the goal state. This is all a screenshot can tell you.
    public var goalVisibleAtEnd: Bool

    public init(journeyID: String, environment: Environment = .default, events: [Event], goalVisibleAtEnd: Bool = true) {
        self.journeyID = journeyID
        self.environment = environment
        self.events = events
        self.goalVisibleAtEnd = goalVisibleAtEnd
    }
}
