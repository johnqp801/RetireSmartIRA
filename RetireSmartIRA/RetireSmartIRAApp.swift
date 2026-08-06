//
//  RetireSmartIRAApp.swift
//  RetireSmartIRA
//
//  Main app entry point
//

import SwiftUI
import StoreKit

// MARK: - Cross-platform color support
#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
extension NSColor {
    static let systemBackground = NSColor.windowBackgroundColor
    static let systemGroupedBackground = NSColor.controlBackgroundColor
    static let systemGray5 = NSColor.separatorColor
    static let secondarySystemBackground = NSColor.controlBackgroundColor
}
typealias PlatformColor = NSColor
#endif

@main
struct RetireSmartIRAApp: App {
    @State private var reviewPrompt = ReviewPromptManager()
    @State private var dataManager: DataManager = {
        #if DEBUG
        if DemoProfile.isActive {
            let dm = DataManager(skipPersistence: true)
            DemoProfile.reset(into: dm)
            return dm
        }
        #endif
        return DataManager()
    }()
    @StateObject private var termsManager = TermsAcceptanceManager()

    var body: some Scene {
        WindowGroup {
            // CARET-AT-END IS APPLIED EXACTLY ONCE, HERE, AND THAT IS DELIBERATE.
            //
            // `.caretAtEndOnFocus()` is not a per-field or per-screen modifier the
            // way `.dismissableKeyboard()` is. It installs ONE observer of the
            // process-wide `UITextField.textDidBeginEditingNotification` and acts on
            // whichever field the notification carries, so its reach is the app, not
            // the subtree it is attached to. The only thing the attachment point
            // decides is HOW LONG the observer lives. Attached to the WindowGroup's
            // root content, that is the whole session, which is why fields inside
            // sheets and popovers (the taxable-account editor, the year detail
            // editor, the add-income sheet, Social Security data entry) are covered
            // even though a sheet does not inherit modifiers from its presenter.
            //
            // So do NOT add `.caretAtEndOnFocus()` to individual screens. A second
            // application is harmless but buys nothing: both observers assign the
            // same end-of-document selection. `CaretAtEndCoverageTests` pins this
            // file as the single call site.
            //
            // The Group keeps one stable identity across the terms-acceptance flip,
            // so the observer is not torn down and reinstalled when the branch
            // changes. No-op on macOS, where a click already places the caret where
            // the user clicked.
            Group {
                if termsManager.hasAcceptedCurrentTerms {
                    ContentView()
                        .environment(dataManager)
                        .environment(reviewPrompt)
                        .environmentObject(termsManager)
                } else {
                    ClickwrapView(manager: termsManager)
                }
            }
            .caretAtEndOnFocus()
        }
    }
}
