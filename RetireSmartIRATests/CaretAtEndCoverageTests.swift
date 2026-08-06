//
//  CaretAtEndCoverageTests.swift
//  RetireSmartIRATests
//
//  THE DEFECT. A trailing-aligned numeric field that is pre-filled puts most of
//  its tappable area to the LEFT of the digits, and iOS places the caret nearest
//  the tap. So a tap on a state-tax-rate field showing "3" usually lands at
//  position 0, and the next keystroke is INSERTED IN FRONT: typing 8 commits
//  0.83, i.e. 83 percent, silently and with no validation to catch it. Reported
//  by Alan Levy on 2026-07-19.
//
//  WHY THIS FILE READS SOURCE RATHER THAN MEASURING A CARET. The fix is a UIKit
//  notification observer wrapped in a SwiftUI ViewModifier. Caret position lives
//  on a UITextField that only exists once UIKit has instantiated the field and
//  made it first responder, inside a running app, on iOS. The suite runs on
//  macOS, where the whole modifier compiles to `self`. There is no handle a unit
//  test can reach. Rather than fake one, this file pins the STRUCTURE that makes
//  the runtime behaviour possible, and says plainly at the bottom what it does
//  not prove.
//
//  WHAT THE STRUCTURE IS, AND WHY ONE CALL SITE IS THE WHOLE FIX.
//  `.caretAtEndOnFocus()` subscribes to `UITextField.textDidBeginEditingNotification`,
//  which is process-wide and carries the field that began editing as its object.
//  Its reach therefore does NOT depend on where it is attached; the attachment
//  point decides only how long the subscription lives. Attached to the
//  WindowGroup's root content, that is the entire session, which covers fields
//  presented in sheets and popovers even though those do not inherit modifiers
//  from the presenting view. That is the single most likely way a root-level fix
//  could have missed screens, and it is the reason it does not: the observer
//  never consults the view hierarchy at all.
//
//  The gates below therefore pin three things:
//    1. The root call site EXISTS and sits in the WindowGroup body.
//    2. It is NOT inside the terms-acceptance branch, so it is not torn down and
//       reinstalled, and it covers the clickwrap screen too.
//    3. It is the ONLY call site. Not because a second would break anything (two
//       observers make the same assignment) but because scattering it per-screen
//       is the misreading this design invites, and the next person to add a
//       numeric screen must not believe they have to.
//
//  Reading production source from `#filePath` is the pattern established by
//  `StateAccuracyContentTests.noMultiYearSurfacePresentsTheAccuracyPage`; the
//  sweep helper here is the same one, reproduced because that one is private.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Caret-at-end coverage")
struct CaretAtEndCoverageTests {

    // MARK: - Markers

    /// An APPLICATION of the modifier. The leading dot is what separates it from
    /// the declaration in `CaretAtEnd.swift` (`func caretAtEndOnFocus()`).
    /// Comment lines are stripped before this is looked for, so the prose in
    /// `CaretAtEnd.swift` and `RetireSmartIRAApp.swift` that quotes the call does
    /// not register as a call site.
    static let applicationMarker = ".caretAtEndOnFocus()"

    /// The one file entitled to apply it.
    static let filesApplyingCaretAtEnd: Set<String> = ["RetireSmartIRAApp.swift"]

    /// The file that DEFINES it, kept separate so a gate cannot confuse the two.
    static let definingFile = "CaretAtEnd.swift"

    /// Every production file that declares a pre-filled numeric `TextField`, and
    /// so exhibited the defect before this fix. Listed not because any of them
    /// needs its own call site (none does, and none has one) but so that a
    /// rename or deletion makes this gate RED rather than quietly narrowing what
    /// "covered" means. `SettingsView.swift` is here on the same footing as the
    /// rest: it briefly carried its own call site as the first, partial fix, and
    /// no longer does.
    static let filesWithPrefilledNumericFields: Set<String> = [
        "AccountsView.swift",
        "ConversionApproachSection.swift",
        "IncomeSourcesView.swift",
        "MultiYearPlanSections.swift",
        "QuarterlyTaxView.swift",
        "RothConversionView.swift",
        "SSDataEntryView.swift",
        "SettingsView.swift",
        "TaxPlanningView.swift",
        "TaxableAccountsSection.swift",
        "Year1EditorView.swift",
        "YearDetailEditor.swift"
    ]

    // MARK: - Source sweep

    /// Every `.swift` file under the production target, by base name, with
    /// full-line comments stripped.
    ///
    /// Resolved from the checkout through `#filePath`, the same way
    /// `StateAccuracyContentTests` reaches production source, because the
    /// subject is Swift source and nothing in the built product carries it.
    private static func productionSources() throws -> [(name: String, text: String, code: String)] {
        struct ProductionTreeMissing: Error { let path: String }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // RetireSmartIRATests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("RetireSmartIRA")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw ProductionTreeMissing(path: root.path)
        }
        var files: [(name: String, text: String, code: String)] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            let url = root.appendingPathComponent(relative)
            let text = try String(contentsOf: url, encoding: .utf8)
            files.append((name: url.lastPathComponent, text: text, code: stripComments(text)))
        }
        return files
    }

    /// Drops whole-line `//` and `///` comments. Deliberately crude: it is only
    /// ever asked whether a line of REAL code applies the modifier, and every
    /// mention of the call in prose sits on a line that begins with slashes.
    /// A trailing comment on a line of code is left alone, which is safe in the
    /// conservative direction for the existence checks and would only matter if
    /// someone wrote `// .caretAtEndOnFocus()` after code on one line, which
    /// would be flagged as an extra call site rather than missed.
    private static func stripComments(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The brace-matched body following `marker`, or nil if the marker is absent
    /// or the braces do not balance.
    private static func bracedBody(of marker: String, in text: String) -> String? {
        guard let markerRange = text.range(of: marker) else { return nil }
        var depth = 1
        var index = markerRange.upperBound
        while index < text.endIndex {
            let character = text[index]
            if character == "{" { depth += 1 }
            if character == "}" {
                depth -= 1
                if depth == 0 { return String(text[markerRange.upperBound..<index]) }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func occurrences(of marker: String, in text: String) -> Int {
        var count = 0
        var search = text.startIndex..<text.endIndex
        while let found = text.range(of: marker, range: search) {
            count += 1
            search = found.upperBound..<text.endIndex
        }
        return count
    }

    // MARK: - Gate 1: the sweep is not vacuous

    /// Every source-reading gate fails the same way: the sweep finds nothing and
    /// then passes everything. This runs first and on its own so that failure is
    /// legible rather than showing up as a confusing set difference below.
    @Test("The production source sweep finds the real tree")
    func sweepIsNotVacuous() throws {
        let sources = try Self.productionSources()

        #expect(sources.count > 100,
                """
                The production source sweep found only \(sources.count) files. It resolves the tree \
                from #filePath, so a moved test file or a renamed target makes every gate in this \
                file vacuous rather than red. Fix the path before trusting anything else here.
                """)

        let names = sources.map(\.name)
        #expect(Set(names).count == names.count,
                """
                Two production files share a base name, so the sets in this file are ambiguous about \
                which one they mean. Key these gates on the relative path instead.
                """)

        // The two files this whole gate is about must be among them, by name.
        #expect(names.contains(Self.definingFile),
                "\(Self.definingFile) is gone from the production target, so nothing defines the modifier")
        #expect(names.contains("RetireSmartIRAApp.swift"),
                "RetireSmartIRAApp.swift is gone from the production target, so the app root cannot be checked")

        // And the comment stripper must actually be stripping. CaretAtEnd.swift
        // is mostly a prose header; if the stripper silently became identity,
        // every "is this a call site" answer below would be wrong.
        let caretFile = try #require(sources.first { $0.name == Self.definingFile })
        #expect(caretFile.code.count < caretFile.text.count,
                """
                stripComments removed nothing from \(Self.definingFile), which is mostly a comment \
                header. The call-site gates below distinguish code from prose using this, so they \
                are unreliable until it works.
                """)
        #expect(!caretFile.code.contains(Self.applicationMarker),
                """
                \(Self.definingFile) appears to APPLY the modifier in code. It should only declare \
                it. If the prose quoting the call is now on a line that does not start with slashes, \
                the stripper needs to handle it; otherwise something real changed.
                """)
    }

    // MARK: - Gate 2: the modifier is applied exactly once, at the scene root

    /// SET EQUALITY, in both directions. A missing entry means the app-wide fix
    /// was deleted and Alan Levy's bug is back on every screen at once. An added
    /// entry means someone started applying it per-screen, which is the
    /// misreading this design invites: the observer is process-wide, so a second
    /// call site covers nothing the first did not, and leaving one there teaches
    /// the next person that new screens need their own.
    @Test("Exactly one production file applies the caret-at-end modifier")
    func caretAtEndIsAppliedOnlyAtTheAppRoot() throws {
        let sources = try Self.productionSources()

        var applying: Set<String> = []
        for file in sources where file.code.contains(Self.applicationMarker) {
            applying.insert(file.name)
        }

        #expect(applying == Self.filesApplyingCaretAtEnd,
                """
                The set of production files applying \(Self.applicationMarker) changed. \
                Added: \(applying.subtracting(Self.filesApplyingCaretAtEnd).sorted()). \
                Missing: \(Self.filesApplyingCaretAtEnd.subtracting(applying).sorted()). \
                MISSING means the caret fix stopped shipping: a pre-filled trailing-aligned rate \
                field takes the first keystroke IN FRONT of its value, so typing 8 into a field \
                showing 3 commits 83 percent silently. It was promised in writing to a named beta \
                tester and already missed one release. \
                ADDED means a per-screen call site came back. Read CaretAtEnd.swift first: the \
                modifier observes a process-wide notification, so the root call already covers that \
                screen, including if it is presented as a sheet.
                """)
    }

    /// The call site must sit in the WindowGroup body and OUTSIDE the
    /// terms-acceptance branch. Inside the branch it would be torn down and
    /// reinstalled on acceptance, and one arm of it would go uncovered.
    @Test("The root call site is in the WindowGroup body, outside the terms branch")
    func rootCallSiteIsPlacedWhereItLivesForTheWholeSession() throws {
        let sources = try Self.productionSources()
        let app = try #require(sources.first { $0.name == "RetireSmartIRAApp.swift" },
                               "RetireSmartIRAApp.swift is gone from the production target")

        let window = try #require(Self.bracedBody(of: "WindowGroup {", in: app.code),
                                  """
                                  WindowGroup could not be parsed out of RetireSmartIRAApp.swift. If the \
                                  scene was restructured, update this gate deliberately rather than \
                                  letting it go vacuous: it is the only thing proving the caret fix is \
                                  attached somewhere that lives for the whole session.
                                  """)

        // NON-VACUITY for the parse itself.
        #expect(window.count > 100,
                "the WindowGroup body parsed to \(window.count) characters, too small to be the real scene")
        #expect(window.contains("ContentView()"),
                "the WindowGroup body no longer builds ContentView, so this parse is not the real scene")

        #expect(Self.occurrences(of: Self.applicationMarker, in: window) == 1,
                """
                RetireSmartIRAApp.swift applies \(Self.applicationMarker) \
                \(Self.occurrences(of: Self.applicationMarker, in: window)) times inside WindowGroup, \
                expected exactly one. Zero means it moved outside the scene, where its lifetime is no \
                longer the session.
                """)

        let acceptedArm = try #require(
            Self.bracedBody(of: "if termsManager.hasAcceptedCurrentTerms {", in: window),
            "the terms-acceptance branch is gone from the WindowGroup body; update this gate deliberately")
        #expect(!acceptedArm.contains(Self.applicationMarker),
                """
                The caret modifier moved INSIDE the accepted-terms arm. It then does not exist until \
                terms are accepted, and it is reinstalled when they are, rather than being attached \
                to a view whose identity is stable for the session. Hoist it back out of the branch.
                """)
    }

    // MARK: - Gate 3: the macOS no-op survives

    /// macOS is a first-class target here. The modifier is UIKit-only and must
    /// keep its `#else` arm, or the Mac build stops compiling the moment anyone
    /// touches the file.
    @Test("CaretAtEnd keeps both an iOS implementation and a macOS no-op")
    func bothPlatformArmsExist() throws {
        let sources = try Self.productionSources()
        let file = try #require(sources.first { $0.name == Self.definingFile })

        #expect(file.code.contains("#if os(iOS)"),
                "\(Self.definingFile) no longer guards its UIKit implementation with #if os(iOS)")
        #expect(file.code.contains("#else"),
                "\(Self.definingFile) lost its non-iOS arm, so the macOS build has no caretAtEndOnFocus()")
        #expect(file.code.contains("import UIKit"),
                "\(Self.definingFile) no longer imports UIKit, so it cannot be observing UITextField")
        #expect(file.code.contains("textDidBeginEditingNotification"),
                """
                \(Self.definingFile) no longer observes textDidBeginEditingNotification. That \
                notification is what makes ONE call site cover the whole app; if the mechanism \
                changed to anything hierarchy-scoped, the single root call site is no longer \
                sufficient and every gate in this file is measuring the wrong thing.
                """)

        // Two declarations of caretAtEndOnFocus(), one per platform arm.
        #expect(Self.occurrences(of: "func caretAtEndOnFocus()", in: file.code) == 2,
                """
                Expected exactly two declarations of caretAtEndOnFocus(), the iOS one and the macOS \
                no-op, found \(Self.occurrences(of: "func caretAtEndOnFocus()", in: file.code)).
                """)
    }

    // MARK: - Gate 4: the covered population is real and stays real

    /// The claim "one call site covers every pre-filled numeric field" is only
    /// worth anything if that population is enumerated and still exists. Each
    /// file must be present and must still declare a `TextField`; a rename that
    /// silently narrowed the claim shows up here as a named failure rather than
    /// as nothing at all.
    ///
    /// This also asserts NONE of them carries its own call site, which is the
    /// same fact as Gate 2 stated per-file so the failure names the screen.
    @Test("Every screen with pre-filled numeric fields exists and relies on the root call site")
    func numericScreensAreEnumeratedAndRelyOnTheRoot() throws {
        let sources = try Self.productionSources()

        #expect(Self.filesWithPrefilledNumericFields.count == 12,
                "the enumerated numeric-field population changed size; update it deliberately")

        for name in Self.filesWithPrefilledNumericFields.sorted() {
            let file = try #require(sources.first { $0.name == name },
                                    """
                                    \(name) no longer exists under the production target. It was one of \
                                    the screens holding a pre-filled numeric TextField when the \
                                    caret-at-end fix was completed. If it was renamed, rename it here \
                                    too; Gate 2 still holds the real gate, but this list stops naming \
                                    the right screens.
                                    """)
            #expect(file.code.contains("TextField("),
                    """
                    \(name) no longer declares a TextField. Either the fields moved to another file, in \
                    which case name that file here, or this entry is stale and should be removed \
                    deliberately.
                    """)
            #expect(!file.code.contains(Self.applicationMarker),
                    """
                    \(name) applies \(Self.applicationMarker) itself. The root call site in \
                    RetireSmartIRAApp.swift already covers it, including if it is presented as a sheet, \
                    because the modifier observes a process-wide notification rather than a view \
                    subtree. Remove the per-screen call.
                    """)
        }
    }

    // MARK: - WHAT THIS FILE DOES NOT PROVE
    //
    // Stated here so its passing is never mistaken for evidence of the fix
    // working, which is a different claim.
    //
    // 1. IT PROVES NOTHING ABOUT CARET POSITION. No assertion here observes a
    //    UITextField, a selectedTextRange, or a keystroke. It proves the
    //    modifier is applied at a place whose lifetime is the session, and that
    //    the mechanism it relies on is still the process-wide notification.
    // 2. IT PROVES NOTHING ON DEVICE. The suite runs against the macOS
    //    destination, where the entire modifier is `self`. The iOS arm is not
    //    even compiled by this test run.
    // 3. IT CANNOT SEE A UIKIT BEHAVIOUR CHANGE. If a future iOS release stopped
    //    posting textDidBeginEditingNotification for SwiftUI-hosted fields, or
    //    set its initial selection after the runloop turn the modifier defers
    //    by, every gate here would still be green and the bug would be back.
    // 4. IT DOES NOT COVER UITextView. `TextEditor` and multiline
    //    `TextField(axis:)` are outside the mechanism entirely. There are none
    //    holding numbers today; a future one would need its own answer, and
    //    nothing here would notice.
    //
    // The only evidence for the runtime behaviour is manual: tap into a
    // pre-filled trailing-aligned field on iOS and type a digit. The report at
    // docs/superpowers/reports/2026-08-06-caret-at-end-completion.md records
    // what was and was not checked that way.
}
