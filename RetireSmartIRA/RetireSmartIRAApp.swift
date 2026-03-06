//
//  RetireSmartIRAApp.swift
//  RetireSmartIRA
//
//  Main app entry point
//

import SwiftUI

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
    @StateObject private var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
        }
    }
}
