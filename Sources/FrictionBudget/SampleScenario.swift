/// A constructed example: ten journeys for a small iOS PDF-markup app, and traces for two builds.
///
/// The "agent draft" build is the kind of first pass the source experiment describes: every
/// feature exists and every final screenshot looks right. The traces are hand-written to model
/// that, not recorded from a real app or a real agent.
public enum SampleScenario {
    public static let journeys: [Journey] = [
        Journey(id: "insert-image", goal: "Insert a photo, then move it where it belongs",
                budget: Budget(maxInputs: 5, everyCreationReachable: true)),
        Journey(id: "redact-cancel", goal: "Start a redaction, change your mind, cancel",
                budget: Budget(cancelLeavesNoTrace: true)),
        Journey(id: "find-dark-mode", goal: "Turn on dark mode from a cold start",
                budget: Budget(maxInputs: 3)),
        Journey(id: "open-large", goal: "Open a 300-page contract and see page 1",
                budget: Budget(maxSecondsToFirstResult: 1.0)),
        Journey(id: "delete-page", goal: "Delete the wrong page, then get it back",
                budget: Budget(destructiveNeedsUndo: true)),
        Journey(id: "sign-compact", goal: "Sign a form in Split View",
                budget: Budget(requiredControls: ["Sign", "Done"])),
        Journey(id: "highlight", goal: "Highlight a sentence",
                budget: Budget(maxInputs: 3)),
        Journey(id: "comment", goal: "Leave a comment on a paragraph",
                budget: Budget(maxInputs: 4, everyCreationReachable: true)),
        Journey(id: "rotate-page", goal: "Rotate a scanned page",
                budget: Budget(maxInputs: 3, destructiveNeedsUndo: true)),
        Journey(id: "share", goal: "Share the marked-up PDF with a colleague",
                budget: Budget(maxInputs: 4, maxSecondsToFirstResult: 1.0), needsHumanReview: true),
    ]

    public static let large = Environment(contentScale: 3)
    public static let splitView = Environment(width: .compact, largeText: true)

    /// The first build: complete on paper, green in every screenshot.
    public static let agentDraft: [Trace] = [
        Trace(journeyID: "insert-image", events: [
            .input("Insert"), .input("Photo"), .input("tap page to place"),
            .created("image-1"), .reach("image-1", succeeded: false),
        ]),
        Trace(journeyID: "redact-cancel", events: [
            .stateDigest("doc-a1"), .input("Redact"), .input("drag box"), .input("Cancel"), .cancel,
            .stateDigest("doc-a1+box"),
        ]),
        Trace(journeyID: "find-dark-mode", events: [
            .input("Settings"), .input("Display"), .input("Appearance"), .input("More"), .input("Dark"),
        ]),
        Trace(journeyID: "open-large", environment: large, events: [
            .input("contract.pdf"), .firstResult(seconds: 2.6),
        ]),
        Trace(journeyID: "delete-page", events: [
            .input("Pages"), .input("page 3"), .input("Delete"), .destructive("page 3", undoable: false),
        ]),
        Trace(journeyID: "sign-compact", environment: splitView, events: [
            .input("Sign"), .input("draw signature"), .notHittable("Done"),
        ]),
        Trace(journeyID: "highlight", events: [.input("Highlight"), .input("drag across sentence")]),
        Trace(journeyID: "comment", events: [
            .input("Comment"), .input("tap paragraph"), .input("type text"),
            .created("comment-1"), .reach("comment-1", succeeded: true),
        ]),
        Trace(journeyID: "rotate-page", events: [
            .input("page 2"), .input("Rotate"), .destructive("rotation", undoable: true),
        ]),
        Trace(journeyID: "share", events: [
            .input("Share"), .firstResult(seconds: 0.4), .input("Messages"), .input("Send"),
        ]),
    ]

    /// The build after the agent was handed the six failing journeys as acceptance criteria.
    public static let afterBudgets: [Trace] = [
        Trace(journeyID: "insert-image", events: [
            .input("Insert"), .input("Photo"), .created("image-1"),
            .input("drag image"), .reach("image-1", succeeded: true),
        ]),
        Trace(journeyID: "redact-cancel", events: [
            .stateDigest("doc-a1"), .input("Redact"), .input("drag box"), .input("Cancel"), .cancel,
            .stateDigest("doc-a1"),
        ]),
        Trace(journeyID: "find-dark-mode", events: [
            .input("Search"), .input("type \"dark\""), .input("Dark"),
        ]),
        Trace(journeyID: "open-large", environment: large, events: [
            .input("contract.pdf"), .firstResult(seconds: 0.7),
        ]),
        Trace(journeyID: "delete-page", events: [
            .input("Pages"), .input("page 3"), .input("Delete"), .destructive("page 3", undoable: true),
            .input("Undo"),
        ]),
        Trace(journeyID: "sign-compact", environment: splitView, events: [
            .input("Sign"), .input("draw signature"), .input("Done"),
        ]),
        agentDraft[6], agentDraft[7], agentDraft[8], agentDraft[9],
    ]

    public static func gate(signedOff: Set<String> = []) -> FrictionGate {
        FrictionGate(journeys: journeys, humanSignOffs: signedOff)
    }
}
