//
//  KeyboardDismiss.swift
//  RetireSmartIRA
//
//  Reusable "Done" accessory for the iOS number/decimal keypads, which have no
//  return key of their own. Without this, a numeric field (e.g. a birth year on
//  the Profile screen) traps the keyboard open with no way to dismiss it short
//  of force-quitting the app. macOS has no software keyboard, so this is a
//  no-op there.
//
//  Usage: apply `.dismissableKeyboard()` once per screen (ideally at a single
//  high-level container, such as a tab's root view or a sheet's NavigationStack,
//  rather than scattering it across every individual field). The accessory bar
//  resigns whichever text field currently has focus, so it works for any
//  number of fields on the screen without per-field FocusState wiring.
//

import SwiftUI

#if os(iOS)
import UIKit

private struct DismissableKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
    }
}

extension View {
    /// Adds a "Done" button above iOS number/decimal keypads so the keyboard can
    /// always be dismissed. No-op on macOS (no software keyboard to dismiss).
    func dismissableKeyboard() -> some View {
        modifier(DismissableKeyboardModifier())
    }
}
#else
extension View {
    /// No-op on macOS, since there is no software keyboard to dismiss.
    func dismissableKeyboard() -> some View {
        self
    }
}
#endif
