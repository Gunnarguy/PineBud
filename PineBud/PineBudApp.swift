//
//  PineBudApp.swift
//  PineBud
//
//  Created by Gunnar Hostetler on 3/23/25.
//

import SwiftUI

@main
struct PineBudApp: App {
    @StateObject private var apiManager = APIManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var searchManager = SearchManager()
    
    var body: some Scene {
        WindowGroup {
            if settingsManager.isFirstLaunch || !settingsManager.areAPIKeysSet {
                OnboardingView()
                    .environmentObject(apiManager)
                    .environmentObject(settingsManager)
            } else {
                ContentView()
                    .environmentObject(apiManager)
                    .environmentObject(settingsManager)
                    .environmentObject(documentManager)
                    .environmentObject(searchManager)
            }
        }
    }
}
