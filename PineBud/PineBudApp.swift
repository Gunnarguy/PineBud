//
//  PineBudApp.swift
//  PineBud
//
//  Created by Gunnar Hostetler on 3/23/25.
//

import SwiftUI
import UIKit

@main
struct PineBudApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var apiManager = APIManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var searchManager = SearchManager()
    
    init() {
        // Improve logging for debugging
        print("PineBudApp initializing...")
        
        // Configure global app appearance
        configureGlobalAppearance()
    }
    
    private func configureGlobalAppearance() {
        // Additional appearance configurations if needed
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
    }
    
    var body: some Scene {
        WindowGroup {
            if settingsManager.isFirstLaunch || !settingsManager.areAPIKeysSet {
                OnboardingView()
                    .environmentObject(apiManager)
                    .environmentObject(settingsManager)
                    .onAppear {
                        print("Displaying OnboardingView")
                    }
            } else {
                ContentView()
                    .environmentObject(apiManager)
                    .environmentObject(settingsManager)
                    .environmentObject(documentManager)
                    .environmentObject(searchManager)
                    .onAppear {
                        print("Displaying ContentView")
                    }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                print("App became active")
            case .inactive:
                print("App became inactive")
            case .background:
                print("App went to background")
                // Save any pending state
            @unknown default:
                print("Unknown scene phase")
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
}
