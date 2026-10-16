import SwiftUI
import FrictionBudget

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(build: UserDefaults.standard.string(forKey: "build") == "fixed" ? .fixed : .draft,
                     detail: UserDefaults.standard.string(forKey: "detail"))
        }
    }
}

enum Build: String, CaseIterable, Identifiable {
    case draft = "Agent draft"
    case fixed = "After budgets"
    var id: String { rawValue }
    var traces: [Trace] { self == .draft ? SampleScenario.agentDraft : SampleScenario.afterBudgets }
}

struct RootView: View {
    @State private var build: Build
    @State private var signedOff = false
    @State private var path: [String]

    init(build: Build, detail: String?) {
        _build = State(initialValue: build)
        _path = State(initialValue: detail.map { [$0] } ?? [])
    }

    private var gate: FrictionGate { SampleScenario.gate(signedOff: signedOff ? ["share"] : []) }
    private var rows: [FrictionGate.Row] { gate.rows(for: build.traces) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Picker("Build", selection: $build) {
                        ForEach(Build.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    SummaryCard(summary: GateSummary(rows), decision: gate.decide(build.traces))
                    Toggle("A person signed off \"share\"", isOn: $signedOff)
                }
                Section("Journeys") {
                    ForEach(rows) { row in
                        NavigationLink(value: row.id) { JourneyRow(row: row) }
                    }
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("Constructed example: hand-written traces for a small PDF-markup app, not recordings of a real app or agent.")
                }
            }
            .navigationTitle("Friction budget")
            .navigationDestination(for: String.self) { id in
                if let row = rows.first(where: { $0.id == id }) {
                    JourneyDetail(row: row)
                } else {
                    Text("Unknown journey")
                }
            }
        }
    }
}

struct SummaryCard: View {
    let summary: GateSummary
    let decision: FrictionGate.Decision

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Screenshot check", systemImage: "camera.viewfinder")
                Spacer()
                Text("\(summary.screenshotGreen)/\(summary.total) green").monospacedDigit()
                    .foregroundStyle(.green)
            }
            HStack {
                Label("Friction budget", systemImage: "gauge.with.needle")
                Spacer()
                Text("\(summary.passed) pass · \(summary.failed) fail · \(summary.awaitingHuman) human")
                    .monospacedDigit()
                    .foregroundStyle(summary.failed > 0 ? Color.red : Color.primary)
            }
            switch decision {
            case .ship:
                Label("Gate: ship", systemImage: "checkmark.seal.fill").foregroundStyle(.green).bold()
            case let .blocked(failing, waiting, missing):
                Label("Gate: blocked. \(failing.count) over budget, \(waiting.count) awaiting a person\(missing.isEmpty ? "" : ", \(missing.count) untested")",
                      systemImage: "hand.raised.fill")
                    .foregroundStyle(failing.isEmpty ? Color.orange : Color.red).bold()
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct JourneyRow: View {
    let row: FrictionGate.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.journey.goal).font(.subheadline)
                Spacer()
            }
            HStack(spacing: 6) {
                Badge(text: row.screenshotPasses ? "screenshot ✓" : "screenshot ✗",
                      color: row.screenshotPasses ? .green : .red)
                VerdictBadge(verdict: row.verdict)
                if let env = row.trace?.environment, !env.isDefault {
                    Text(env.description).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if case .fail(let violations) = row.verdict, let first = violations.first {
                Text(first.description).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }
}

struct VerdictBadge: View {
    let verdict: FrictionGate.Verdict
    var body: some View {
        switch verdict {
        case .pass: Badge(text: "budget ✓", color: .green)
        case .fail: Badge(text: "over budget", color: .red)
        case .awaitingHuman: Badge(text: "needs a person", color: .orange)
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

struct JourneyDetail: View {
    let row: FrictionGate.Row

    var body: some View {
        List {
            Section("Goal") {
                Text(row.journey.goal)
                if let env = row.trace?.environment {
                    LabeledContent("Environment", value: env.description)
                }
            }
            Section("Budget") {
                ForEach(budgetLines, id: \.self) { Text($0).font(.callout) }
            }
            Section("Verdicts") {
                LabeledContent("Screenshot check", value: row.screenshotPasses ? "pass" : "fail")
                switch row.verdict {
                case .pass: LabeledContent("Friction budget", value: "pass")
                case .awaitingHuman: LabeledContent("Friction budget", value: "within budget, waiting for a person")
                case .fail(let violations):
                    ForEach(violations, id: \.self) { v in
                        Label(v.description, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                    }
                }
            }
            if let trace = row.trace {
                Section("Recorded trace") {
                    ForEach(Array(trace.events.enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            Text(describe(event)).font(.callout.monospaced())
                        }
                    }
                }
            }
        }
        .navigationTitle(row.journey.id)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var budgetLines: [String] {
        let b = row.journey.budget
        var lines: [String] = []
        if let n = b.maxInputs { lines.append("At most \(n) inputs") }
        if let s = b.maxSecondsToFirstResult { lines.append("First result within \(s.formatted()) s") }
        if b.everyCreationReachable { lines.append("Everything you create can be selected and moved") }
        if b.cancelLeavesNoTrace { lines.append("Cancel leaves the document unchanged") }
        if b.destructiveNeedsUndo { lines.append("Every destructive action has a one-step undo") }
        if !b.requiredControls.isEmpty { lines.append("Hittable: \(b.requiredControls.joined(separator: ", "))") }
        if row.journey.needsHumanReview { lines.append("A person signs off that it's pleasant") }
        return lines
    }

    private func describe(_ event: Event) -> String {
        switch event {
        case .input(let s): return "input  \(s)"
        case .firstResult(let s): return "result at \(s.formatted()) s"
        case .created(let id): return "created  \(id)"
        case let .reach(id, ok): return "reach \(id): \(ok ? "ok" : "STUCK")"
        case let .destructive(id, undo): return "destroy \(id) \(undo ? "(undo offered)" : "(NO undo)")"
        case .stateDigest(let d): return "state  \(d)"
        case .cancel: return "cancel"
        case .notHittable(let c): return "NOT hittable: \(c)"
        }
    }
}
