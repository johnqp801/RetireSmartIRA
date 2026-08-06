//
//  CaretAtEnd.swift
//  RetireSmartIRA
//
//  Places the caret at the END of a text field's existing value when the user
//  taps into it, rather than wherever the tap happened to land.
//
//  Numeric fields here are trailing-aligned and pre-filled (a rate shows "0",
//  a balance shows its current amount), so the tappable area sits mostly to the
//  LEFT of the digits. iOS puts the caret nearest the tap, which means tapping
//  the field usually lands at position 0 and the next keystroke is INSERTED IN
//  FRONT of the existing value: a field showing "0" becomes "30" when the user
//  types 3, i.e. 30% instead of 3%. The value commits immediately and silently,
//  with no validation to catch it.
//
//  The user can recover by tapping directly to the right of the digits, but
//  should not have to. Caret-at-end makes the common case (append, or backspace
//  and retype) behave the way the field looks like it should.
//
//  Usage: apply `.caretAtEndOnFocus()` ONCE, at the WindowGroup root in
//  RetireSmartIRAApp.swift. It is already applied there and needs no further
//  call sites.
//
//  It is NOT per-screen, whatever its earlier note here said, and it is not
//  analogous to `.dismissableKeyboard()`. That one attaches a keyboard-placement
//  toolbar, which really is scoped to the subtree it is applied to. This one
//  subscribes to `UITextField.textDidBeginEditingNotification`, a process-wide
//  notification carrying the field that began editing as its object. Nothing
//  about the reach depends on where it is attached; the attachment point only
//  decides how long the subscription lives, and at the scene root that is the
//  whole session. Which is why fields inside sheets and popovers are covered
//  even though those do not inherit modifiers from the presenting view.
//
//  Consequences worth knowing, since they are properties of the whole app:
//
//  * It fires on textDidBeginEditing, which is the moment a field becomes first
//    responder. A second tap in an already-focused field posts no notification,
//    so repositioning the caret mid-string still works normally. Only the first
//    tap into a field is overridden.
//  * It applies to every UITextField, including the non-numeric ones (name,
//    institution, description). Caret-at-end is the right default there too:
//    those are short single-line values, appending is the common edit, and
//    landing at the end is what a trailing tap would have done anyway.
//  * It does not reach UITextView, so `TextEditor` and any multiline
//    `TextField(axis:)` are unaffected. There are none holding numbers.
//
//  No-op on macOS, where clicking a field already places the caret where the
//  click landed and the tap-lands-left problem does not arise.
//

import SwiftUI

#if os(iOS)
import UIKit

private struct CaretAtEndModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onReceive(
            NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
        ) { note in
            guard let field = note.object as? UITextField else { return }
            // Deferred a runloop turn: UIKit sets its own initial selection as part of
            // beginning editing, so setting it synchronously here would be overwritten.
            DispatchQueue.main.async {
                field.selectedTextRange = field.textRange(from: field.endOfDocument,
                                                          to: field.endOfDocument)
            }
        }
    }
}

extension View {
    /// Puts the caret after the existing text when a field gains focus, so the first
    /// keystroke appends instead of inserting in front of a pre-filled value.
    func caretAtEndOnFocus() -> some View {
        modifier(CaretAtEndModifier())
    }
}
#else
extension View {
    /// No-op on macOS.
    func caretAtEndOnFocus() -> some View {
        self
    }
}
#endif
