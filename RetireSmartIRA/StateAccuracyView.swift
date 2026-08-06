import SwiftUI

/// The per-state accuracy page: what tax treatment this app applies for one
/// jurisdiction and one tax year, and what known limitations could affect it.
///
/// COMPOSES NO COPY OF ITS OWN. Every string on screen comes from
/// `StateAccuracyContent`, which is pure, view-free and tested. That split is
/// not tidiness: the six pension-editor captions this feature consolidates were
/// unreachable inline literals in a SwiftUI body, two Phase 5b reviews recorded
/// that as a gap, and Task 1 of this plan existed only to undo it. Putting a
/// dollar format, a plural, or an empty-state sentence back into this file
/// would recreate the same untestable surface.
///
/// The view therefore makes layout decisions only. The one branch it owns is
/// whether the limitations half renders as a bulleted list or as a single
/// paragraph, and both strings come from `StateAccuracyContent` either way.
///
/// `state` IS A PARAMETER, NEVER READ FROM `DataManager`. Three call sites
/// present this page and they resolve three different jurisdictions: the State
/// Comparison sheet shows the state being INSPECTED, not where the user lives.
/// A comparison sheet opened on Oregon must never show California's
/// disclosure. Task 7 wires those call sites to their own resolvers.
struct StateAccuracyView: View {
    /// The jurisdiction this page describes. See the type note above.
    let state: USState
    /// The filing status whose bracket, deduction and exemption columns are
    /// reported, because every one of those is filing-status specific.
    let filingStatus: FilingStatus

    @Environment(\.dismiss) private var dismiss

    private var header: StateAccuracyContent.Header {
        StateAccuracyContent.header(for: state)
    }

    private var statements: [StateAccuracyContent.Statement] {
        StateAccuracyContent.factualStatements(for: state, filingStatus: filingStatus)
    }

    private var limitations: [String] {
        StateAccuracyContent.limitations(for: state)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    modelledSection
                    limitationsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("State tax accuracy")
            #if os(iOS)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Provenance

    /// State and tax year arrive as ONE string from `StateAccuracyContent`, and
    /// are rendered as one `Text`. Splitting them across two views would let a
    /// later layout change separate them, which is the failure this design
    /// names explicitly: "verified August 2026" beside a bare "Iowa" reads as a
    /// claim about Iowa's current law generally.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header.title)
                .font(.title3.weight(.semibold))

            Text(header.verified)
                .font(.caption)
                .foregroundStyle(.secondary)

            if header.sources.isEmpty {
                Text(header.noSourcesMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(header.sources) { source in
                        sourceRow(source)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// A source with no resolvable URL still shows its name. Dropping it would
    /// hide a citation the configuration does carry.
    @ViewBuilder
    private func sourceRow(_ source: StateAccuracyContent.Header.Source) -> some View {
        if let url = source.url {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 6) {
                    Text(source.label)
                        .font(.caption)
                        .foregroundStyle(Color.UI.brandTeal)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundStyle(Color.UI.brandTeal.opacity(0.6))
                }
            }
        } else {
            Text(source.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - What we model

    private var modelledSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What we model")
                .font(.headline)

            ForEach(statements) { statement in
                VStack(alignment: .leading, spacing: 2) {
                    Text(statement.label)
                        .font(.subheadline.weight(.semibold))
                    Text(statement.value)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Known limitations

    /// THE EMPTY STATE NEVER READS AS A CLEAN BILL OF HEALTH, and this is the
    /// only place the page could accidentally imply one.
    ///
    /// The branch below chooses a list or a paragraph. It does NOT choose the
    /// words: the empty case renders
    /// `StateAccuracyContent.limitationsSummary(for:)`, whose exact sentence is
    /// John's and is pinned by test. An empty `knownLimitations` records what
    /// has not been FOUND for a jurisdiction, never that nothing exists, and
    /// Iowa and Indiana ship empty lists while carrying full verification
    /// metadata, so this path is reached inside the covered set and not only
    /// for the thirty-six jurisdictions outside it.
    private var limitationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Known limitations")
                .font(.headline)

            if limitations.isEmpty {
                Text(StateAccuracyContent.limitationsSummary(for: state))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(limitations, id: \.self) { limitation in
                    Label {
                        Text(limitation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.Semantic.amber)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Covered jurisdiction with limitations") {
    StateAccuracyView(state: .kansas, filingStatus: .single)
}

#Preview("Covered jurisdiction with an empty list") {
    StateAccuracyView(state: .iowa, filingStatus: .marriedFilingJointly)
}

#Preview("Uncovered jurisdiction, no stated tax year") {
    StateAccuracyView(state: .pennsylvania, filingStatus: .single)
}
