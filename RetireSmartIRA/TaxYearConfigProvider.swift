//
//  TaxYearConfigProvider.swift
//  RetireSmartIRA
//
//  Supplies the `TaxYearConfig` for any projection year, so the multi-year engine
//  resolves tax-year configuration explicitly instead of reading the single global
//  `TaxCalculationEngine.config` static.
//
//  Why this exists
//  ---------------
//  `TaxCalculationEngine.config` is a process-global, set-once-at-startup single-year
//  config. That is fine for the single-year Scenarios/Tax Summary engine, but the
//  multi-year engine projects across decades and (today) flattens every year onto that
//  one config. Reading the global static from inside the multi-year engine also made the
//  engine's tests order-dependent (a TEST-ONLY `TaxCalculationEngine.withConfig(forYear:)`
//  swap in one test could bleed into another under parallel execution).
//
//  This provider removes that hidden global dependency: the engine becomes a pure function
//  of (inputs, config provider). Tests inject a deterministic provider; production keeps
//  today's behavior via `.current`.
//
//  Future development
//  ------------------
//  The provider is the seam for genuine per-year tax law. Today `.current` returns the same
//  config for every year (preserving the existing flat-config, no-CPI-projection behavior).
//  When per-year brackets / inflation indexing land, swap the engine's default to `.bundled`
//  (or a CPI-projecting provider) without touching any call site or the single-year engine.
//
//  Sendable: holds an immutable resolver closure. `.current` reads the static at call time.
//
struct TaxYearConfigProvider: Sendable {
    private let resolve: @Sendable (Int) -> TaxYearConfig

    init(resolve: @escaping @Sendable (Int) -> TaxYearConfig) {
        self.resolve = resolve
    }

    /// The tax-year configuration to use for `year`.
    func config(forYear year: Int) -> TaxYearConfig { resolve(year) }

    /// Returns the active app-startup config (`TaxCalculationEngine.config`) for **every** year.
    /// This preserves today's multi-year behavior exactly (one config flattened across all years,
    /// no per-year tax law, no CPI projection). It is the default for all engine entry points, so
    /// adopting the provider changes no production behavior.
    static var current: TaxYearConfigProvider {
        TaxYearConfigProvider { _ in TaxCalculationEngine.config }
    }

    /// Resolves each year's own bundled JSON (falling back to hardcoded values where a year is
    /// not bundled). The forward-looking seam for genuine per-year tax law — not yet the default.
    static var bundled: TaxYearConfigProvider {
        TaxYearConfigProvider { year in TaxYearConfig.loadOrFallback(forYear: year) }
    }

    /// A fixed config for every year. Used by tests to pin a deterministic config so engine
    /// results never depend on global static state or test execution order.
    static func fixed(_ config: TaxYearConfig) -> TaxYearConfigProvider {
        TaxYearConfigProvider { _ in config }
    }
}
