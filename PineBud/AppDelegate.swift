import UIKit
import os.log

class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.universalrag.PineBud", category: "AppDelegate")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        logger.info("Application did finish launching")
        
        // Configure app settings
        configureNavigationBarAppearance()
        
        // Setup crash handling/reporting
        setupExceptionHandler()
        
        // Request necessary permissions early
        requestPermissions()
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        logger.info("Application will terminate")
        // Perform cleanup tasks
        cleanupBeforeTermination()
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func setupExceptionHandler() {
        // Setup global exception handler
        NSSetUncaughtExceptionHandler { exception in
            // Log the exception
            let logger = Logger(subsystem: "com.universalrag.PineBud", category: "Crash")
            logger.error("Uncaught exception: \(exception.name.rawValue), reason: \(exception.reason ?? "unknown")")
        }
    }
    
    private func requestPermissions() {
        // Request any permissions needed by the app
        // This can include file access permissions, camera access, etc.
        
        // For permission requests that require user interaction, 
        // you might want to delay these until they're actually needed
    }
    
    private func cleanupBeforeTermination() {
        // Save any unsaved data
        // Close open connections
        // Release any resources that need manual cleanup
        logger.info("Cleanup completed before termination")
    }
}
