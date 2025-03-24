import SwiftUI

struct ContentView: View {
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var searchManager: SearchManager
    
    @State private var selectedTab = 0
    @State private var showSettingsSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Documents Tab
            NavigationView {
                DocumentsView()
                    .navigationTitle("Documents")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showSettingsSheet = true
                            }) {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Documents", systemImage: "doc.text")
            }
            .tag(0)
            
            // Indexes Tab
            NavigationView {
                IndexesView()
                    .navigationTitle("Indexes")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showSettingsSheet = true
                            }) {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Indexes", systemImage: "list.bullet")
            }
            .tag(1)
            
            // Search Tab
            NavigationView {
                SearchView()
                    .navigationTitle("Search")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showSettingsSheet = true
                            }) {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(2)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .alert(item: $apiManager.currentError) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
