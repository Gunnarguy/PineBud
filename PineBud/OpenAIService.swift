// MARK: - DocumentsContainerView.swift
import SwiftUI

struct DocumentsContainerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var viewMode = 0 // 0 = All Documents, 1 = By Namespace
    
    var body: some View {
        VStack(spacing: 0) {
            // View mode switcher
            Picker("View Mode", selection: $viewMode) {
                Text("All Documents").tag(0)
                Text("By Namespace").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Divider between picker and content
            Divider()
            
            // Content area
            if viewMode == 0 {
                DocumentsView()
            } else {
                NamespaceDocumentsView()
            }
        }
        .navigationTitle(viewMode == 0 ? "Documents" : "Documents by Namespace")
    }
}
