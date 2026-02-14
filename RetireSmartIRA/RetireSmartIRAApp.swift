//
//  RetireSmartIRAApp.swift
//  RetireSmartIRA
//
//  Main app entry point
//

import SwiftUI

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
