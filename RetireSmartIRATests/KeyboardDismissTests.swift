import Testing
import SwiftUI
@testable import RetireSmartIRA

/// Smoke tests for `.dismissableKeyboard()` (RetireSmartIRA/KeyboardDismiss.swift).
///
/// The modifier's only real behavior is a UIKit side effect (resigning the first
/// responder from a keyboard-toolbar "Done" button), which has no pure logic to
/// assert against without an on-device / XCUITest harness this project doesn't
/// have. These tests are a compile-and-attach smoke check, mirroring the existing
/// `ColorTokenUITests` convention: prove the modifier exists, is callable on any
/// `View`, and doesn't crash when composed into a real view hierarchy. Actual
/// "does a Done button appear above the number pad and dismiss it" behavior is
/// verified manually on a real iOS keyboard (see task-1-report.md).
@Suite("Keyboard dismiss modifier")
@MainActor
struct KeyboardDismissTests {

    @Test("dismissableKeyboard() is callable on any View and returns a View")
    func modifierIsCallableOnAnyView() {
        let plain = Text("0")
        let modified = plain.dismissableKeyboard()
        // Type-erase to prove the modifier composes without a compile-time
        // constraint mismatch; the real assertion is that this line compiles.
        _ = AnyView(modified)
    }

    @Test("dismissableKeyboard() composes with an existing .toolbar without crashing")
    func modifierComposesWithExistingToolbar() {
        struct HostView: View {
            var body: some View {
                NavigationStack {
                    TextField("0", text: .constant(""))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {}
                            }
                        }
                        .dismissableKeyboard()
                }
            }
        }
        _ = AnyView(HostView())
    }
}
