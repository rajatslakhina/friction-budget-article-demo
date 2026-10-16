/// What an agent concludes when it verifies UI by looking at a final, static screenshot.
///
/// It is deliberately generous, because that is how this check behaves in practice: the
/// goal is on screen, nothing looks clipped in the one configuration it rendered, so it's done.
/// It cannot see input counts, timing, whether a placed object can be moved, what Cancel left
/// behind, or whether undo exists. It only renders the default environment.
public enum ScreenshotOracle {
    public static func passes(_ trace: Trace) -> Bool {
        guard trace.goalVisibleAtEnd else { return false }
        if trace.environment.isDefault {
            return TraceMetrics(trace).notHittable.isEmpty
        }
        // The agent rendered the default configuration, not the one this journey runs in.
        return true
    }
}
