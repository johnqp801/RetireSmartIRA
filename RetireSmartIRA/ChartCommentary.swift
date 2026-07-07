import Foundation

/// Plain-language explanation of a chart, generated deterministically from the chart's own model.
/// Pure value type; the view presents it (see ChartInfoButton). No LLM, offline, instant.
struct ChartCommentary: Equatable, Sendable {
    let title: String
    let body: String
}
