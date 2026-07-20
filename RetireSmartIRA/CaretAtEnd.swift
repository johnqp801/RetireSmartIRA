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
//  Usage: apply `.caretAtEndOnFocus()` once per screen, like
//  `.dismissableKeyboard()`. It keys off the system's begin-editing
//  notification, so it covers every text field on that screen without
//  per-field FocusState wiring. No-op on macOS, where tapping a field already
//  places the caret sensibly and the accessory-bar problem does not exist.
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
