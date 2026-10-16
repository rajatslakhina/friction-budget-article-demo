import XCTest
@testable import FrictionBudget

final class TraceMetricsTests: XCTestCase {
    func testCountsInputsAndKeepsEarliestResult() {
        let trace = Trace(journeyID: "j", events: [
            .input("a"), .firstResult(seconds: 1.5), .input("b"), .firstResult(seconds: 0.9),
        ])
        let m = TraceMetrics(trace)
        XCTAssertEqual(m.inputs, 2)
        XCTAssertEqual(m.secondsToFirstResult, 0.9)
    }

    func testStuckCreationNeedsASuccessfulReach() {
        let trace = Trace(journeyID: "j", events: [
            .created("x"), .reach("x", succeeded: false), .created("y"), .reach("y", succeeded: true),
        ])
        XCTAssertEqual(TraceMetrics(trace).stuckCreations, ["x"])
    }

    func testCreationNeverReachedCountsAsStuck() {
        let trace = Trace(journeyID: "j", events: [.created("x")])
        XCTAssertEqual(TraceMetrics(trace).stuckCreations, ["x"])
    }

    func testResidueOnlyWhenCancelled() {
        let changedNoCancel = Trace(journeyID: "j", events: [.stateDigest("a"), .stateDigest("b")])
        XCTAssertFalse(TraceMetrics(changedNoCancel).cancelLeftResidue)
        let changedWithCancel = Trace(journeyID: "j", events: [.stateDigest("a"), .cancel, .stateDigest("b")])
        XCTAssertTrue(TraceMetrics(changedWithCancel).cancelLeftResidue)
    }

    func testEnvironmentClampsScaleAndDescribesItself() {
        XCTAssertEqual(Environment(contentScale: 0).contentScale, 1)
        XCTAssertTrue(Environment(contentScale: -4).isDefault)
        XCTAssertEqual(Environment(contentScale: 3, width: .compact).description, "3× content, compact width")
    }
}

final class FrictionCheckTests: XCTestCase {
    func testEachBudgetLine() {
        let journey = Journey(id: "j", goal: "g", budget: Budget(
            maxInputs: 1, maxSecondsToFirstResult: 1, everyCreationReachable: true,
            destructiveNeedsUndo: true, requiredControls: ["Done"]))
        let trace = Trace(journeyID: "j", events: [
            .input("a"), .input("b"), .firstResult(seconds: 2), .created("x"),
            .destructive("p", undoable: false), .notHittable("Done"), .notHittable("Other"),
        ])
        XCTAssertEqual(FrictionCheck.violations(of: journey, in: trace), [
            .tooManyInputs(used: 2, limit: 1), .slowFirstResult(seconds: 2, limit: 1),
            .stuckCreation("x"), .irreversible("p"), .notHittable("Done"),
        ])
    }

    func testLatencyBudgetWithNoResultFails() {
        let journey = Journey(id: "j", goal: "g", budget: Budget(maxSecondsToFirstResult: 1))
        XCTAssertEqual(FrictionCheck.violations(of: journey, in: Trace(journeyID: "j", events: [])), [.noResult])
    }

    func testCancelWithoutDigestsIsUnverifiedNotPassed() {
        let journey = Journey(id: "j", goal: "g", budget: Budget(cancelLeavesNoTrace: true))
        let trace = Trace(journeyID: "j", events: [.input("Cancel"), .cancel])
        XCTAssertEqual(FrictionCheck.violations(of: journey, in: trace), [.cancelUnverified])
    }

    func testWrongJourneyIsRejected() {
        let journey = Journey(id: "a", goal: "g", budget: Budget())
        XCTAssertEqual(FrictionCheck.violations(of: journey, in: Trace(journeyID: "b", events: [])),
                       [.wrongJourney(expected: "a", got: "b")])
    }

    func testNegativeBudgetsClampToZero() {
        XCTAssertEqual(Budget(maxInputs: -3).maxInputs, 0)
        XCTAssertEqual(Budget(maxSecondsToFirstResult: -1).maxSecondsToFirstResult, 0)
    }

    func testViolationFormatting() {
        XCTAssertEqual(Violation.slowFirstResult(seconds: 2.6, limit: 1).description, "first result at 2.6 s, budget 1.0 s")
    }
}

final class ScreenshotOracleTests: XCTestCase {
    func testOnlySeesDefaultEnvironmentLayout() {
        let clippedDefault = Trace(journeyID: "j", events: [.notHittable("Done")])
        XCTAssertFalse(ScreenshotOracle.passes(clippedDefault))
        let clippedCompact = Trace(journeyID: "j", environment: Environment(width: .compact), events: [.notHittable("Done")])
        XCTAssertTrue(ScreenshotOracle.passes(clippedCompact))
        XCTAssertFalse(ScreenshotOracle.passes(Trace(journeyID: "j", events: [], goalVisibleAtEnd: false)))
    }
}

final class ScenarioTests: XCTestCase {
    func testDraftIsScreenshotGreenButBlowsSixBudgets() {
        let rows = SampleScenario.gate().rows(for: SampleScenario.agentDraft)
        let summary = GateSummary(rows)
        XCTAssertEqual(summary.total, 10)
        XCTAssertEqual(summary.screenshotGreen, 10)
        XCTAssertEqual(summary.failed, 6)
        XCTAssertEqual(summary.passed, 3)
        XCTAssertEqual(summary.awaitingHuman, 1)
        XCTAssertEqual(summary.byKind.map(\.kind), ["cancel", "inputs", "latency", "layout", "reachability", "undo"])
        XCTAssertEqual(summary.byKind.map(\.count), [1, 1, 1, 1, 1, 1])
    }

    func testDraftViolationsMatchTheArticle() {
        let fails = SampleScenario.gate().rows(for: SampleScenario.agentDraft).compactMap { row -> [Violation]? in
            if case .fail(let violations) = row.verdict { return violations } else { return nil }
        }
        XCTAssertEqual(fails, [
            [.stuckCreation("image-1")],
            [.cancelLeftResidue],
            [.tooManyInputs(used: 5, limit: 3)],
            [.slowFirstResult(seconds: 2.6, limit: 1.0)],
            [.irreversible("page 3")],
            [.notHittable("Done")],
        ])
    }

    func testDraftFailuresAreTheExpectedJourneys() {
        let decision = SampleScenario.gate().decide(SampleScenario.agentDraft)
        XCTAssertEqual(decision, .blocked(
            failing: ["insert-image", "redact-cancel", "find-dark-mode", "open-large", "delete-page", "sign-compact"],
            awaitingHuman: ["share"], missingTraces: []))
    }

    func testFixedBuildStillWaitsForAPerson() {
        let summary = GateSummary(SampleScenario.gate().rows(for: SampleScenario.afterBudgets))
        XCTAssertEqual(summary.passed, 9)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(SampleScenario.gate().decide(SampleScenario.afterBudgets),
                       .blocked(failing: [], awaitingHuman: ["share"], missingTraces: []))
        XCTAssertEqual(SampleScenario.gate(signedOff: ["share"]).decide(SampleScenario.afterBudgets), .ship)
    }

    func testMissingTraceBlocksInsteadOfPassing() {
        let partial = Array(SampleScenario.afterBudgets.dropFirst())
        let decision = SampleScenario.gate(signedOff: ["share"]).decide(partial)
        XCTAssertEqual(decision, .blocked(failing: [], awaitingHuman: [], missingTraces: ["insert-image"]))
    }

    func testFixedBuildInputCountsStayWithinBudget() {
        let fixed = SampleScenario.afterBudgets
        guard let darkMode = fixed.first(where: { $0.journeyID == "find-dark-mode" }) else {
            return XCTFail("missing trace")
        }
        XCTAssertEqual(TraceMetrics(darkMode).inputs, 3)
    }
}
