import SwiftUI

/// Pure edit state for one year's living-expense override. `resultingOverride` is nil when the user
/// entered nothing, so opening and saving without input creates no override (spec §6).
struct YearOverrideEditModel {
    let year: Int
    /// Baseline "before this year's adjustments": earlier recurring anchors, excluding THIS year's
    /// own recurring level and one-time amount.
    let projectedBeforeThisYear: Double
    var recurringText: String
    var oneTimeText: String

    init(year: Int, existing: YearOverride?, projectedBeforeThisYear: Double) {
        self.year = year
        self.projectedBeforeThisYear = projectedBeforeThisYear
        let le = existing?.livingExpenses
        self.recurringText = le?.recurringLevel.map { Self.fmt($0) } ?? ""
        self.oneTimeText = le?.oneTimeAmount.map { Self.fmt($0) } ?? ""
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
    private static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let d = Double(t), d.isFinite else { return nil }
        return d
    }

    var resultingOverride: YearOverride? {
        let field = FieldOverride(recurringLevel: Self.parse(recurringText), oneTimeAmount: Self.parse(oneTimeText))
        return YearOverride(livingExpenses: field).pruned
    }

    var referenceLabel: String { "Projected before \(year)'s adjustments" }
}

/// Sheet for editing one year's living-expense override. Pure presentation over
/// `YearOverrideEditModel`; the caller supplies `onSave` to write `resultingOverride` into
/// `assumptions.perYearOverrides[year]` (wiring lands in Task 7).
struct YearDetailEditor: View {
    @State private var model: YearOverrideEditModel
    var onSave: (YearOverride?) -> Void

    @Environment(\.dismiss) private var dismiss

    init(year: Int, existing: YearOverride?, projectedBeforeThisYear: Double, onSave: @escaping (YearOverride?) -> Void) {
        _model = State(initialValue: YearOverrideEditModel(
            year: year, existing: existing, projectedBeforeThisYear: projectedBeforeThisYear))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                referenceSection
                recurringField
                oneTimeField
                clearSection
            }
            .navigationTitle("Year \(String(model.year))")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(model.resultingOverride)
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var referenceSection: some View {
        Section {
            LabeledContent(model.referenceLabel) {
                Text(model.projectedBeforeThisYear, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var recurringField: some View {
        Section {
            TextField("Ongoing annual expenses beginning in \(String(model.year))", text: $model.recurringText)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    @ViewBuilder
    private var oneTimeField: some View {
        Section {
            TextField("One-time adjustment in \(String(model.year)) (+/\u{2212})", text: $model.oneTimeText)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
        }
    }

    @ViewBuilder
    private var clearSection: some View {
        Section {
            Button("Clear", role: .destructive) {
                model.recurringText = ""
                model.oneTimeText = ""
            }
        }
    }
}
